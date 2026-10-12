import Foundation
import WidgetKit

enum CatchableWidgetStyle: String {
    case badges, timetable, next
}

struct WidgetDepartureEntry: TimelineEntry {
    let date: Date
    let place: Place
    let snapshot: DepartureSnapshot?
    let message: String?

    func catchableDepartures(for service: SavedService) -> [Departure] {
        guard let snapshot,
              snapshot.isSample || date.timeIntervalSince(snapshot.fetchedAt) < WidgetDataStore.maximumAge else { return [] }
        return DepartureSelector().catchable(snapshot.departures, for: service,
                                             buffer: place.bufferMinutes, now: date)
    }
}

struct CatchableTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetDepartureEntry { preview }

    func getSnapshot(in context: Context, completion: @escaping (WidgetDepartureEntry) -> Void) {
        if context.isPreview { completion(preview); return }
        let store = WidgetDataStore()
        let place = store.loadPlace()
        let now = Date()
        let snapshot = store.loadSnapshot(for: place, now: now)
        completion(WidgetDepartureEntry(date: now, place: place, snapshot: snapshot,
                                        message: snapshot == nil ? "Open Catchable to refresh" : nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetDepartureEntry>) -> Void) {
        Task {
            let store = WidgetDataStore()
            let place = store.loadPlace()
            var snapshot = store.loadSnapshot(for: place)
            var message: String?
            if place.services.contains(where: \.isSelected) {
                do {
                    // The HTTP client has a finite request timeout; requests share the same API as the app.
                    let fresh = try await fetchWithinBudget(place.services.filter(\.isSelected))
                    try? store.saveSnapshot(fresh, for: place, reloadTimelines: false)
                    snapshot = fresh
                } catch { message = "Unable to refresh · Open Catchable" }
            } else { message = "Choose stations in Catchable" }
            let now = Date()
            let entries = (0...30).map { minute -> WidgetDepartureEntry in
                let date = now.addingTimeInterval(Double(minute) * 60)
                let fresh = snapshot.flatMap {
                    date.timeIntervalSince($0.fetchedAt) < WidgetDataStore.maximumAge ? $0 : nil
                }
                return WidgetDepartureEntry(date: date, place: place, snapshot: fresh,
                    message: fresh == nil ? (message ?? "Open Catchable to refresh") : message)
            }
            completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
        }
    }

    private func fetchWithinBudget(_ services: [SavedService]) async throws -> DepartureSnapshot {
        enum RefreshError: Error { case timedOut }
        return try await withThrowingTaskGroup(of: DepartureSnapshot.self) { group in
            group.addTask { try await LiveDepartureProvider().fetchDepartures(for: services) }
            group.addTask {
                try await Task.sleep(for: .seconds(20))
                throw RefreshError.timedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw RefreshError.timedOut }
            return result
        }
    }

    private var preview: WidgetDepartureEntry {
        let now = Date()
        let place = PlaceStore.sample
        let departures = place.services.flatMap { service in
            [8, 18, 28].map { minute in
                Departure(id: "preview-\(service.id)-\(minute)", serviceID: service.id,
                          date: now.addingTimeInterval(Double(service.walkingMinutes + 1 + minute) * 60))
            }
        }
        return WidgetDepartureEntry(date: now, place: place,
            snapshot: DepartureSnapshot(departures: departures, fetchedAt: now, isSample: true), message: nil)
    }
}
