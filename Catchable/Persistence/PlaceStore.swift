import Foundation

struct PlaceStore {
    private let defaults: UserDefaults
    private let key = "catchable.home.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> Place {
        guard let data = defaults.data(forKey: key), let place = try? JSONDecoder().decode(Place.self, from: data)
        else { return Self.sample }
        return place
    }
    func save(_ place: Place) throws {
        defaults.set(try JSONEncoder().encode(place), forKey: key)
    }
    static let sample = Place(label: "Home", address: "", bufferMinutes: 1, services: [
        SavedService(id: "tram-demo", station: "Bersarinplatz", line: "M10", destination: "Warschauer Straße", mode: .tram, walkingMinutes: 5),
        SavedService(id: "subway-demo", station: "Frankfurter Tor", line: "U5", destination: "Hauptbahnhof", mode: .subway, walkingMinutes: 8),
        SavedService(id: "bus-demo", station: "Nearby bus stop", line: "BUS", destination: "City centre", mode: .bus, walkingMinutes: 4)
    ])
}
