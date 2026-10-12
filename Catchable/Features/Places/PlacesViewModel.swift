import Foundation
import Observation

@MainActor @Observable final class PlacesViewModel {
    var place: Place
    var saveError: String?
    private let store: PlaceStore
    init(store: PlaceStore) { self.store = store; place = store.load() }
    func save() {
        do { try store.save(place); saveError = nil }
        catch { saveError = "Could not save your place. Please try again." }
    }
    func addService() {
        place.services.append(SavedService(id: UUID().uuidString, station: "New station", line: "Line", destination: "Direction", mode: .tram, walkingMinutes: 5))
    }
}
