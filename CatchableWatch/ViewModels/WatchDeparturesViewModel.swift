import Foundation
import Observation

@MainActor @Observable
final class WatchDeparturesViewModel {
    private(set) var place = WidgetDataStore().loadPlace()
    private(set) var snapshot: DepartureSnapshot?
    private(set) var isRefreshing = false
    private(set) var message: String?
    private var generation = 0

    func refresh() async {
        generation += 1
        let request = generation
        let store = WidgetDataStore()
        let savedPlace = store.loadPlace()
        place = savedPlace
        snapshot = store.loadSnapshot(for: savedPlace)
        guard savedPlace.services.contains(where: \.isSelected) else {
            message = "Choose stations in Catchable on your iPhone."
            isRefreshing = false
            return
        }
        isRefreshing = true
        message = nil
        defer { if request == generation { isRefreshing = false } }
        do {
            let fresh = try await LiveDepartureProvider().fetchDepartures(for: savedPlace.services.filter(\.isSelected))
            guard request == generation, store.loadPlace() == savedPlace else { return }
            snapshot = fresh
            try? store.saveSnapshot(fresh, for: savedPlace)
        } catch {
            guard request == generation else { return }
            message = "Unable to refresh. Try again."
        }
    }

    func departures(for service: SavedService, now: Date) -> [Departure] {
        guard let snapshot, now.timeIntervalSince(snapshot.fetchedAt) < WidgetDataStore.maximumAge else { return [] }
        return DepartureSelector().catchable(snapshot.departures, for: service, buffer: place.bufferMinutes, now: now)
    }
}
