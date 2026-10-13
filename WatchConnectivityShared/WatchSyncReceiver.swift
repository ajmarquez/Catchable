import Foundation

/// Applies ordered phone updates to the Watch's device-local store.
struct WatchSyncReceiver {
    private let store: WidgetDataStore
    private let defaults: UserDefaults
    private let receivedAtKey = "catchable.watch.receivedAt.v1"

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: WidgetDataStore.groupID) ?? .standard
        store = defaults.map { WidgetDataStore(defaults: $0) } ?? WidgetDataStore()
    }

    @discardableResult func receive(_ data: Data, now: Date = Date()) throws -> Bool {
        let payload = try WatchSyncPayload.decode(data)
        if let previous = defaults.object(forKey: receivedAtKey) as? Date, previous >= payload.sentAt { return false }
        try store.savePlace(payload.place)
        if let incoming = payload.snapshot,
           store.loadSnapshot(for: payload.place, now: now)?.fetchedAt ?? .distantPast <= incoming.fetchedAt {
            try store.saveSnapshot(incoming, for: payload.place)
        }
        defaults.set(payload.sentAt, forKey: receivedAtKey)
        return true
    }
}
