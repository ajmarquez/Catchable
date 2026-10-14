import Foundation
import Observation

@MainActor @Observable final class NowViewModel {
    var snapshot: DepartureSnapshot?
    var isLoading = false
    var errorMessage: String?
    private let provider: any DepartureProvider
    private let selector = DepartureSelector()
    private var generation = 0
    init(provider: any DepartureProvider) { self.provider = provider }
    func refresh(place: Place, sampleMode: Bool = false) async {
        generation += 1
        let request = generation
        snapshot = nil
        isLoading = true
        errorMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let source: any DepartureProvider = sampleMode ? SampleDepartureProvider() : provider
            let result = try await source.fetchDepartures(for: place.services.filter(\.isSelected))
            guard generation == request else { return }
            snapshot = result
            if !sampleMode {
                try? WidgetDataStore().saveSnapshot(result, for: place)
                WatchSyncCoordinator.shared.publishCurrentState()
            }
        } catch is CancellationError { }
        catch { if generation == request { errorMessage = "Departures could not be loaded. Pull down to retry." } }
    }
    func departures(for service: SavedService, place: Place, now: Date) -> [Departure] {
        selector.catchable(snapshot?.departures ?? [], for: service, buffer: place.bufferMinutes, now: now)
    }
    func notices(for services: [SavedService]) -> [ServiceNotice] {
        let ids = Set(services.map(\.id))
        var seen = Set<String>()
        return (snapshot?.notices ?? []).filter { ids.contains($0.serviceID) && seen.insert($0.text).inserted }
    }
}
