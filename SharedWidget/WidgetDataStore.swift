import Foundation
import WidgetKit

/// The app and extension exchange only a saved place and its matching live board.
struct WidgetDataStore {
    static let groupID = "group.com.ajmarquez.catchable"
    static let maximumAge: TimeInterval = 15 * 60
    private let defaults: UserDefaults
    private let legacy: UserDefaults?
    private let placeKey = "catchable.home.v1"
    private let cacheKey = "catchable.widget.departures.v1"

    init(defaults: UserDefaults? = nil, legacy: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: Self.groupID) ?? .standard
        self.legacy = legacy ?? (defaults == nil ? .standard : nil)
    }

    func loadPlace() -> Place {
        if let data = defaults.data(forKey: placeKey),
           let place = try? JSONDecoder().decode(Place.self, from: data) { return place }
        if let data = legacy?.data(forKey: placeKey),
           let place = try? JSONDecoder().decode(Place.self, from: data) {
            defaults.set(data, forKey: placeKey)
            return place
        }
        return Place(label: "Home", address: "", bufferMinutes: 1, services: [])
    }

    func savePlace(_ place: Place) throws {
        let changed = loadPlace() != place
        defaults.set(try JSONEncoder().encode(place), forKey: placeKey)
        if changed { defaults.removeObject(forKey: cacheKey) }
        WidgetCenter.shared.reloadAllTimelines()
    }

    func saveSnapshot(_ snapshot: DepartureSnapshot, for place: Place, reloadTimelines: Bool = true) throws {
        // Ignore previews and responses for a place that changed while loading.
        guard !snapshot.isSample, loadPlace() == place else { return }
        defaults.set(try JSONEncoder().encode(Cache(place: place, snapshot: snapshot)), forKey: cacheKey)
        if reloadTimelines { WidgetCenter.shared.reloadAllTimelines() }
    }

    func loadSnapshot(for place: Place, now: Date = Date()) -> DepartureSnapshot? {
        guard let data = defaults.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(Cache.self, from: data),
              cache.place == place, !cache.snapshot.isSample,
              now.timeIntervalSince(cache.snapshot.fetchedAt) >= -60,
              now.timeIntervalSince(cache.snapshot.fetchedAt) < Self.maximumAge else { return nil }
        return cache.snapshot
    }

    private struct Cache: Codable {
        let place: Place
        let snapshot: DepartureSnapshot
    }
}
