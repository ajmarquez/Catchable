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
        } catch is CancellationError { }
        catch { if generation == request { errorMessage = "Departures could not be loaded. Pull down to retry." } }
    }
    func departures(for service: SavedService, place: Place, now: Date) -> [Departure] {
        selector.catchable(snapshot?.departures ?? [], for: service, buffer: place.bufferMinutes, now: now)
    }
}
