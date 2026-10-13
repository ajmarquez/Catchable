import XCTest
@testable import Catchable

@MainActor final class LocationsStoreTests: XCTestCase {
    func testFailedRouteIsUnavailableAndCannotProduceCatchableDepartures() async throws {
        let (_, store) = try storage()
        let home = configuredPlace(id: "home")
        try store.save(LocationsState(locations: [home], activeLocationID: home.id))
        let vm = PlacesViewModel(locationsStore: store, walkingProvider: UnavailableWalk())
        await vm.recalculateWalkingTimes(locationID: home.id)
        let service = try XCTUnwrap(vm.place.services.first)
        XCTAssertEqual(service.walkingState, .unavailable)
        XCTAssertNotNil(vm.walkingError)
        let departure = Departure(id: "future", serviceID: service.id, date: Date().addingTimeInterval(3600))
        XCTAssertTrue(DepartureSelector().catchable([departure], for: service, buffer: 1, now: Date()).isEmpty)
    }

    private func storage() throws -> (UserDefaults, LocationsStore) {
        let name = "LocationsStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        return (defaults, LocationsStore(defaults: defaults))
    }

    func testLegacyHomeMigratesOncePreservingServicesAndInvalidatingManualWalks() throws {
        let (defaults, store) = try storage()
        let legacy = PlaceStore.sample
        try PlaceStore(defaults: defaults).save(legacy)
        let state = store.load()
        XCTAssertEqual(state.locations.count, 1)
        XCTAssertNotNil(state.activeLocationID)
        XCTAssertEqual(state.locations[0].services.map(\.id), legacy.services.map(\.id))
        XCTAssertTrue(state.locations[0].services.allSatisfy { $0.walkingState == .pending })
        XCTAssertEqual(store.load(), state)
    }

    func testNewInstallStartsEmptyAndFinalDeletionClearsMirror() throws {
        let (defaults, store) = try storage()
        XCTAssertEqual(store.load().locations.count, 0)
        var home = PlaceStore.sample
        home.locationID = "home"
        try store.save(LocationsState(locations: [home], activeLocationID: home.id))
        XCTAssertEqual(PlaceStore(defaults: defaults).load(), home)
        try store.save(LocationsState(locations: [], activeLocationID: "home"))
        XCTAssertTrue(PlaceStore(defaults: defaults).load().services.isEmpty)
        XCTAssertNil(store.load().activeLocationID)
    }

    func testDeletingStationOnlyAffectsItsLocation() async throws {
        let (_, store) = try storage()
        var home = configuredPlace(id: "home")
        home.services[0].stopID = "900000001"
        var work = home
        work.locationID = "work"
        var anotherDirection = home.services[0]
        anotherDirection.id = "second-direction"
        anotherDirection.stopID = "de-VBB_de:11000:900000001"
        home.services.append(anotherDirection)
        try store.save(LocationsState(locations: [home, work], activeLocationID: home.id))
        let vm = PlacesViewModel(locationsStore: store, walkingProvider: FixedWalk())
        vm.deleteStation(stopID: "900000001", from: home.id)
        XCTAssertTrue(vm.locations[0].services.isEmpty)
        XCTAssertEqual(vm.locations[1].services.count, 1)
        vm.deleteLocation(id: home.id)
        XCTAssertEqual(vm.activeLocationID, work.id)
        XCTAssertEqual(store.load().locations, [work])
    }

    func testSameStationRoutesAreCalculatedOnceAndWalkingResultIsPersisted() async throws {
        let (_, store) = try storage()
        var home = configuredPlace(id: "home")
        var second = home.services[0]
        second.id = "second"
        second.destination = "Other direction"
        home.services.append(second)
        try store.save(LocationsState(locations: [home], activeLocationID: home.id))
        let walking = FixedWalk()
        let vm = PlacesViewModel(locationsStore: store, walkingProvider: walking)
        await vm.recalculateWalkingTimes(locationID: home.id)
        XCTAssertEqual(walking.calls, 1)
        XCTAssertTrue(vm.place.services.allSatisfy { $0.walkingMinutes == 7 && $0.walkingState == .calculated && $0.walkingUpdatedAt != nil })
        XCTAssertEqual(store.load().locations, vm.locations)
        XCTAssertFalse(vm.isCalculatingWalking)
    }

    func testDeletedLocationCannotBeRestoredByDelayedWalkingResponse() async throws {
        let (_, store) = try storage()
        let home = configuredPlace(id: "home")
        try store.save(LocationsState(locations: [home], activeLocationID: home.id))
        let walking = SuspendedWalk()
        let vm = PlacesViewModel(locationsStore: store, walkingProvider: walking)
        let task = Task { await vm.recalculateWalkingTimes(locationID: home.id) }
        while walking.continuation == nil { await Task.yield() }
        vm.deleteLocation(id: home.id)
        walking.continuation?.resume(returning: 9)
        await task.value
        XCTAssertTrue(vm.locations.isEmpty)
        XCTAssertTrue(store.load().locations.isEmpty)
    }

    func testEditedOriginRejectsDelayedWalkingResponse() async throws {
        let (_, store) = try storage()
        let home = configuredPlace(id: "home")
        try store.save(LocationsState(locations: [home], activeLocationID: home.id))
        let walking = SuspendedWalk()
        let vm = PlacesViewModel(locationsStore: store, walkingProvider: walking)
        let task = Task { await vm.recalculateWalkingTimes(locationID: home.id) }
        while walking.continuation == nil { await Task.yield() }
        var moved = vm.place
        moved.coordinate = GeoCoordinate(latitude: 52.7, longitude: 13.6)
        vm.place = moved
        vm.save()
        walking.continuation?.resume(returning: 99)
        await task.value
        XCTAssertEqual(vm.place.coordinate, moved.coordinate)
        XCTAssertNotEqual(vm.place.services[0].walkingMinutes, 99)
    }

    func testAddingEquivalentProviderSelectionDoesNotDuplicateService() async throws {
        let (_, store) = try storage()
        let home = configuredPlace(id: "home")
        try store.save(LocationsState(locations: [home], activeLocationID: home.id))
        let walking = FixedWalk()
        let vm = PlacesViewModel(locationsStore: store, walkingProvider: walking)
        var duplicate = home.services[0]
        duplicate.id = UUID().uuidString
        duplicate.stopID = "de-VBB_de:11000:900000001"
        await vm.addService(duplicate, to: home.id)
        XCTAssertEqual(vm.place.services.count, 1)
        XCTAssertEqual(walking.calls, 0)
    }

    func testStationResolutionMatchesIdentityInsteadOfFirstSearchResult() async throws {
        let (_, store) = try storage()
        var home = configuredPlace(id: "home")
        home.services[0].stationCoordinate = nil
        home.services[0].stopID = "900000001"
        try store.save(LocationsState(locations: [home], activeLocationID: home.id))
        let walking = FixedWalk()
        let destination = GeoCoordinate(latitude: 52.6, longitude: 13.5)
        let api = SearchAPI(stops: [
            TransportStop(id: "900000002", name: "Wrong", lat: 53, lon: 14),
            TransportStop(id: "de-VBB_de:11000:900000001", name: "Right", lat: destination.latitude, lon: destination.longitude)
        ])
        let vm = PlacesViewModel(locationsStore: store, walkingProvider: walking, transitAPI: api)
        await vm.recalculateWalkingTimes(locationID: home.id)
        XCTAssertEqual(walking.destination, destination)
        XCTAssertEqual(vm.place.services[0].stationCoordinate, destination)
    }

    private func configuredPlace(id: String) -> Place {
        var service = PlaceStore.sample.services[0]
        service.stopID = "900000001"
        service.stationCoordinate = GeoCoordinate(latitude: 52.53, longitude: 13.42)
        return Place(label: id, address: "Alexanderplatz 1, Berlin", bufferMinutes: 1, services: [service],
            locationID: id, coordinate: GeoCoordinate(latitude: 52.52, longitude: 13.41))
    }
}

@MainActor private struct UnavailableWalk: WalkingTimeProviding {
    func walkingMinutes(from: GeoCoordinate, to: GeoCoordinate) async throws -> Int { throw URLError(.notConnectedToInternet) }
}

@MainActor private final class FixedWalk: WalkingTimeProviding {
    var calls = 0
    var destination: GeoCoordinate?
    func walkingMinutes(from: GeoCoordinate, to: GeoCoordinate) async throws -> Int {
        calls += 1
        destination = to
        return 7
    }
}

@MainActor private final class SuspendedWalk: WalkingTimeProviding {
    var continuation: CheckedContinuation<Int, Error>?
    func walkingMinutes(from: GeoCoordinate, to: GeoCoordinate) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
}

private struct SearchAPI: TransitAPI {
    let stops: [TransportStop]
    func searchStops(_ query: String) async throws -> [TransportStop] { stops }
    func board(stopID: String, minutes: Int) async throws -> TransportBoard { TransportBoard(departures: []) }
}
