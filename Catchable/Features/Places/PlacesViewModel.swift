import Foundation
import Observation

@MainActor @Observable final class PlacesViewModel {
    var locations: [Place]
    var activeLocationID: String?
    var saveError: String?
    var walkingError: String?
    var isCalculatingWalking: Bool { !walkingRequests.isEmpty }
    var place: Place {
        get { locations.first { $0.id == activeLocationID } ?? LocationsStore.emptyPlace }
        set {
            guard let index = locations.firstIndex(where: { $0.id == activeLocationID }) else { return }
            locations[index] = newValue
        }
    }
    private let locationsStore: LocationsStore
    private let walkingProvider: any WalkingTimeProviding
    private let transitAPI: any TransitAPI
    private var walkingRequests: [String: UUID] = [:]

    init(store: PlaceStore = PlaceStore(), locationsStore: LocationsStore? = nil,
         walkingProvider: (any WalkingTimeProviding)? = nil, transitAPI: any TransitAPI = FailoverTransitAPI()) {
        let persistence = locationsStore ?? LocationsStore(mirror: store)
        self.locationsStore = persistence
        self.walkingProvider = walkingProvider ?? MapKitWalkingTimeProvider()
        self.transitAPI = transitAPI
        let state = persistence.load()
        locations = state.locations
        activeLocationID = state.activeLocationID
    }

    func save() {
        do {
            let activeChanged = try locationsStore.save(LocationsState(locations: locations, activeLocationID: activeLocationID))
            saveError = nil
            if activeChanged { WatchSyncCoordinator.shared.publishCurrentState() }
        } catch { saveError = "Could not save your locations. Please try again." }
    }

    func selectLocation(id: String) {
        guard locations.contains(where: { $0.id == id }) else { return }
        activeLocationID = id
        save()
    }

    func resumeWalkingCalculations() async {
        let pending = locations.filter { $0.coordinate != nil && $0.services.contains { $0.walkingState == .pending } }.map(\.id)
        for id in pending {
            guard !Task.isCancelled else { return }
            await recalculateWalkingTimes(locationID: id)
        }
    }

    func saveLocation(_ location: Place) {
        var location = location
        if location.locationID == nil { location.locationID = UUID().uuidString }
        let previous = locations.first { $0.id == location.id }
        let moved = previous?.coordinate != location.coordinate || previous?.address != location.address
        if moved {
            walkingRequests.removeValue(forKey: location.id)
            for index in location.services.indices {
                location.services[index].walkingState = .pending
                location.services[index].walkingUpdatedAt = nil
            }
        }
        if let index = locations.firstIndex(where: { $0.id == location.id }) { locations[index] = location }
        else { locations.append(location) }
        if activeLocationID == nil { activeLocationID = location.id }
        save()
        if moved, !location.services.isEmpty {
            let id = location.id
            Task { await self.recalculateWalkingTimes(locationID: id) }
        }
    }

    func deleteLocation(id: String) {
        walkingRequests.removeValue(forKey: id)
        locations.removeAll { $0.id == id }
        if activeLocationID == id { activeLocationID = locations.first?.id }
        save()
    }

    func addService(_ service: SavedService, to locationID: String) async {
        guard let index = locations.firstIndex(where: { $0.id == locationID }),
              !locations[index].services.contains(where: { sameSelection($0, service) }) else { return }
        var service = service
        service.walkingState = .pending
        service.walkingUpdatedAt = nil
        locations[index].services.append(service)
        save()
        await recalculateWalkingTimes(locationID: locationID)
    }

    func deleteStation(stopID: String, from locationID: String) {
        guard let index = locations.firstIndex(where: { $0.id == locationID }) else { return }
        let identity = StopReference(stopID)?.vbbID
        locations[index].services.removeAll { service in
            if let identity { return service.stopID.flatMap { StopReference($0)?.vbbID } == identity }
            return service.stopID == stopID || (service.stopID == nil && service.station == stopID)
        }
        save()
    }

    func recalculateWalkingTimes(locationID: String) async {
        guard let location = locations.first(where: { $0.id == locationID }) else { return }
        let request = UUID()
        walkingRequests[locationID] = request
        walkingError = nil
        defer { if walkingRequests[locationID] == request { walkingRequests.removeValue(forKey: locationID) } }
        let grouped = Dictionary(grouping: location.services, by: { $0.stopID.flatMap { StopReference($0)?.vbbID } ?? $0.stopID ?? $0.id })
        for services in grouped.values {
            guard !Task.isCancelled, walkingRequests[locationID] == request, let service = services.first else { return }
            var stationCoordinate = service.stationCoordinate
            var minutes: Int?
            var failed = false
            do {
                guard let origin = location.coordinate, origin.isValid else { throw WalkingFailure.missingCoordinate }
                if stationCoordinate == nil {
                    let matches = try await transitAPI.searchStops(service.station)
                    stationCoordinate = matchingCoordinate(matches, service: service)
                }
                guard let destination = stationCoordinate, destination.isValid else { throw WalkingFailure.missingCoordinate }
                minutes = max(1, try await walkingProvider.walkingMinutes(from: origin, to: destination))
            } catch is CancellationError { return }
            catch { failed = true }
            guard !Task.isCancelled, walkingRequests[locationID] == request,
                  let index = locations.firstIndex(where: { $0.id == locationID }),
                  locations[index].coordinate == location.coordinate, locations[index].address == location.address else { return }
            if failed { walkingError = "Some walking times could not be calculated. Check the location address and try again." }
            for original in services {
                guard let serviceIndex = locations[index].services.firstIndex(where: { $0.id == original.id }),
                      locations[index].services[serviceIndex].stopID == original.stopID,
                      locations[index].services[serviceIndex].stationCoordinate == original.stationCoordinate else { continue }
                locations[index].services[serviceIndex].stationCoordinate = stationCoordinate
                locations[index].services[serviceIndex].walkingState = minutes == nil ? .unavailable : .calculated
                locations[index].services[serviceIndex].walkingUpdatedAt = minutes == nil ? nil : Date()
                if let minutes { locations[index].services[serviceIndex].walkingMinutes = minutes }
            }
            save()
        }
    }

    private func sameSelection(_ lhs: SavedService, _ rhs: SavedService) -> Bool {
        let lhsStop = lhs.stopID.flatMap { StopReference($0)?.vbbID } ?? lhs.stopID
        let rhsStop = rhs.stopID.flatMap { StopReference($0)?.vbbID } ?? rhs.stopID
        return lhs.id == rhs.id || (lhsStop != nil && lhsStop == rhsStop && lhs.mode == rhs.mode &&
            lhs.line.caseInsensitiveCompare(rhs.line) == .orderedSame &&
            FailoverTransitAPI.destinationKey(lhs.destination) == FailoverTransitAPI.destinationKey(rhs.destination))
    }

    private func matchingCoordinate(_ stops: [TransportStop], service: SavedService) -> GeoCoordinate? {
        guard let stopID = service.stopID, let identity = StopReference(stopID)?.vbbID else { return nil }
        return stops.first { StopReference($0.id)?.vbbID == identity }?.coordinate
    }

    private enum WalkingFailure: Error { case missingCoordinate }
}
