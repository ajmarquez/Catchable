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
}
