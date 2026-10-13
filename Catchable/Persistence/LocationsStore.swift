import Foundation

struct LocationsState: Codable, Equatable {
    var locations: [Place]
    var activeLocationID: String?
}

/// Owns locations; PlaceStore is the active-place mirror for widgets and Apple Watch.
struct LocationsStore {
    private let defaults: UserDefaults
    private let mirror: PlaceStore
    private let key = "catchable.locations.v1"

    init(defaults: UserDefaults? = nil, mirror: PlaceStore? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: WidgetDataStore.groupID) ?? .standard
        self.mirror = mirror ?? PlaceStore(defaults: defaults)
    }

    func load() -> LocationsState {
        if let data = defaults.data(forKey: key), let state = try? JSONDecoder().decode(LocationsState.self, from: data) {
            return normalized(state)
        }
        var legacy = mirror.load()
        guard !legacy.services.isEmpty || !legacy.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return LocationsState(locations: [], activeLocationID: nil)
        }
        legacy.locationID = UUID().uuidString
        if legacy.coordinate == nil {
            for index in legacy.services.indices {
                legacy.services[index].walkingState = .pending
                legacy.services[index].walkingUpdatedAt = nil
            }
        }
        let migrated = LocationsState(locations: [legacy], activeLocationID: legacy.id)
        _ = try? save(migrated)
        return migrated
    }

    @discardableResult func save(_ state: LocationsState) throws -> Bool {
        let valid = normalized(state)
        // Persist the authoritative collection before changing the shared active board.
        defaults.set(try JSONEncoder().encode(valid), forKey: key)
        let active = valid.locations.first { $0.id == valid.activeLocationID } ?? Self.emptyPlace
        let changed = mirror.load() != active
        if changed { try mirror.save(active) }
        return changed
    }

    private func normalized(_ state: LocationsState) -> LocationsState {
        var state = state
        if !state.locations.contains(where: { $0.id == state.activeLocationID }) {
            state.activeLocationID = state.locations.first?.id
        }
        return state
    }

    static var emptyPlace: Place { Place(label: "Home", address: "", bufferMinutes: 1, services: []) }
}
