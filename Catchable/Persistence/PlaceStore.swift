import Foundation

struct PlaceStore {
    private let shared: WidgetDataStore
    init(defaults: UserDefaults? = nil) {
        shared = defaults.map { WidgetDataStore(defaults: $0) } ?? WidgetDataStore()
    }
    func load() -> Place { shared.loadPlace() }
    func save(_ place: Place) throws { try shared.savePlace(place) }
    static let sample = Place(label: "Home", address: "", bufferMinutes: 1, services: [
        SavedService(id: "tram-demo", station: "Bersarinplatz", line: "M10", destination: "Warschauer Straße", mode: .tram, walkingMinutes: 5),
        SavedService(id: "subway-demo", station: "Frankfurter Tor", line: "U5", destination: "Hauptbahnhof", mode: .subway, walkingMinutes: 8),
        SavedService(id: "bus-demo", station: "Nearby bus stop", line: "BUS", destination: "City centre", mode: .bus, walkingMinutes: 4)
    ])
}
