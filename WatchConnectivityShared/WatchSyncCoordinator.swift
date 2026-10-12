import Foundation
import WatchConnectivity

extension Notification.Name {
    static let catchableWatchStateDidChange = Notification.Name("catchable.watchStateDidChange")
}

/// Runs in the containing apps only. Widget extensions read their device's local store.
@MainActor final class WatchSyncCoordinator: NSObject {
    static let shared = WatchSyncCoordinator()
    private let store = WidgetDataStore()
    private var started = false
    private let contextKey = "catchable.state.v1"
    private let receivedAtKey = "catchable.watch.receivedAt.v1"

    func start() {
        guard WCSession.isSupported(), !started else { return }
        started = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    #if os(watchOS)
    /// Keep the SwiftUI background task alive while WCSession drains pending content.
    /// The deadline leaves room for the system to suspend us without an endless task.
    func handleBackgroundDelivery() async {
        guard WCSession.isSupported() else { return }
        start()
        let session = WCSession.default
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(20))
        while !Task.isCancelled, clock.now < deadline {
            if session.activationState == .activated {
                receive(session.receivedApplicationContext)
                if !session.hasContentPending { break }
            }
            // Yield the main actor so delegate callbacks can persist incoming state.
            do { try await Task.sleep(for: .milliseconds(100)) }
            catch { break }
        }
        // Drain the context once more: a delegate callback may have been queued
        // just before hasContentPending became false or cancellation arrived.
        if session.activationState == .activated {
            receive(session.receivedApplicationContext)
        }
    }
    #endif

    func publishCurrentState() {
        #if os(iOS)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled,
              let data = encodedCurrentState() else { return }
        // The system delivers the latest context even when the watch is unreachable.
        try? session.updateApplicationContext([contextKey: data])
        #endif
    }

    private func encodedCurrentState() -> Data? {
        let place = store.loadPlace()
        return try? JSONEncoder().encode(WatchSyncPayload(place: place, snapshot: store.loadSnapshot(for: place)))
    }

    private func receive(_ context: [String: Any]) {
        #if os(watchOS)
        guard let data = context[contextKey] as? Data,
              let payload = try? WatchSyncPayload.decode(data) else { return }
        let defaults = UserDefaults(suiteName: WidgetDataStore.groupID) ?? .standard
        if let previous = defaults.object(forKey: receivedAtKey) as? Date, previous >= payload.sentAt { return }
        do {
            try store.savePlace(payload.place)
            if let snapshot = payload.snapshot {
                // Don't replace a newer board fetched directly by the watch.
                if store.loadSnapshot(for: payload.place)?.fetchedAt ?? .distantPast <= snapshot.fetchedAt {
                    try store.saveSnapshot(snapshot, for: payload.place)
                }
            }
            defaults.set(payload.sentAt, forKey: receivedAtKey)
            NotificationCenter.default.post(name: .catchableWatchStateDidChange, object: nil)
        } catch {
            // Keep the prior revision so the next delivery can retry persistence.
        }
        #endif
    }

    private func requestCurrentState() {
        #if os(watchOS)
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(["request": "currentState"], replyHandler: { [weak self] context in
            Task { @MainActor in self?.receive(context) }
        }, errorHandler: { _ in
            // applicationContext remains the durable, background delivery path.
        })
        #endif
    }
}

extension WatchSyncCoordinator: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            #if os(iOS)
            self.publishCurrentState()
            #elseif os(watchOS)
            self.receive(session.receivedApplicationContext)
            self.requestCurrentState()
            #endif
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.receive(applicationContext) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.requestCurrentState() }
    }

    #if os(iOS)
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.publishCurrentState() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            guard message["request"] as? String == "currentState", let data = self.encodedCurrentState() else {
                replyHandler([:])
                return
            }
            replyHandler([self.contextKey: data])
        }
    }
    #endif
}
