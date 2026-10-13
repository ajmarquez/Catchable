import XCTest
@testable import Catchable

@MainActor final class LocationIntegrationTests: XCTestCase {
    func testSelectionPersistsActiveLocationAndInvalidatesPreviousWidgetBoard() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let home = location(id: "home", latitude: 52.5)
        let work = location(id: "work", latitude: 52.6)
        try fixture.store.save(LocationsState(locations: [home, work], activeLocationID: home.id))
        let now = Date()
        try fixture.widgets.saveSnapshot(board(now: now), for: home, reloadTimelines: false)
        XCTAssertNotNil(fixture.widgets.loadSnapshot(for: home, now: now))

        let vm = PlacesViewModel(locationsStore: fixture.store, walkingProvider: OriginWalkingProvider())
        vm.selectLocation(id: work.id)

        XCTAssertEqual(fixture.store.load().activeLocationID, work.id)
        XCTAssertEqual(PlaceStore(defaults: fixture.defaults).load(), work)
        XCTAssertNil(fixture.widgets.loadSnapshot(for: home, now: now))
        XCTAssertNil(fixture.widgets.loadSnapshot(for: work, now: now))
        let reopened = PlacesViewModel(locationsStore: fixture.store, walkingProvider: OriginWalkingProvider())
        XCTAssertEqual(reopened.place, work)
        XCTAssertEqual(reopened.activeLocationID, work.id)
    }

    func testEditingInactiveWorkPreservesHomeWidgetBoard() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let home = location(id: "home", latitude: 52.5)
        var work = location(id: "work", latitude: 52.6)
        try fixture.store.save(LocationsState(locations: [home, work], activeLocationID: home.id))
        let now = Date()
        let snapshot = board(now: now)
        try fixture.widgets.saveSnapshot(snapshot, for: home, reloadTimelines: false)
        let vm = PlacesViewModel(locationsStore: fixture.store, walkingProvider: OriginWalkingProvider())

        work.label = "Office"
        work.bufferMinutes = 4
        vm.saveLocation(work)

        XCTAssertEqual(fixture.store.load().locations.first { $0.id == work.id }, work)
        XCTAssertEqual(fixture.store.load().activeLocationID, home.id)
        XCTAssertEqual(PlaceStore(defaults: fixture.defaults).load(), home)
        XCTAssertEqual(fixture.widgets.loadSnapshot(for: home, now: now)?.departures, snapshot.departures)
        XCTAssertEqual(fixture.widgets.loadSnapshot(for: home, now: now)?.fetchedAt, now)
    }

    func testCalculatedWalkAndEachLocationsBufferDriveCatchableFeed() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        var home = location(id: "home", latitude: 52.5)
        var work = location(id: "work", latitude: 52.6)
        home.bufferMinutes = 4
        work.bufferMinutes = 4
        home.services[0].walkingState = .pending
        work.services[0].walkingState = .pending
        try fixture.store.save(LocationsState(locations: [home, work], activeLocationID: home.id))
        let routing = OriginWalkingProvider()
        let places = PlacesViewModel(locationsStore: fixture.store, walkingProvider: routing)
        await places.recalculateWalkingTimes(locationID: home.id)
        await places.recalculateWalkingTimes(locationID: work.id)
        XCTAssertEqual(routing.calls, 2)
        XCTAssertEqual(places.locations.first { $0.id == home.id }?.services[0].walkingMinutes, 7)
        XCTAssertEqual(places.locations.first { $0.id == work.id }?.services[0].walkingMinutes, 17)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let feed = NowViewModel(provider: SampleDepartureProvider())
        feed.snapshot = board(now: now)

        XCTAssertEqual(feed.departures(for: places.place.services[0], place: places.place, now: now).map(\.id), ["15", "20", "25"])
        places.selectLocation(id: work.id)
        XCTAssertEqual(feed.departures(for: places.place.services[0], place: places.place, now: now).map(\.id), ["25", "30"])
        places.selectLocation(id: home.id)
        XCTAssertEqual(feed.departures(for: places.place.services[0], place: places.place, now: now).map(\.id), ["15", "20", "25"])
    }

    func testDeletedStationNeverReturnsWhenWalkingResponseArrives() async throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let home = location(id: "home", latitude: 52.5)
        try fixture.store.save(LocationsState(locations: [home], activeLocationID: home.id))
        let started = expectation(description: "Walking request started")
        let routing = DelayedWalkingProvider { started.fulfill() }
        let vm = PlacesViewModel(locationsStore: fixture.store, walkingProvider: routing)
        let calculation = Task { await vm.recalculateWalkingTimes(locationID: home.id) }
        await fulfillment(of: [started], timeout: 2)
        // A different provider ID for the same station exercises identity-based removal.
        vm.deleteStation(stopID: "de-VBB_de:11000:900000001", from: home.id)
        XCTAssertTrue(vm.place.services.isEmpty)
        routing.finish(minutes: 8)
        await calculation.value

        XCTAssertTrue(vm.place.services.isEmpty)
        XCTAssertTrue(try XCTUnwrap(fixture.store.load().locations.first).services.isEmpty)
        XCTAssertTrue(PlaceStore(defaults: fixture.defaults).load().services.isEmpty)
        XCTAssertFalse(vm.isCalculatingWalking)
    }

    private func location(id: String, latitude: Double) -> Place {
        let service = SavedService(id: "route", station: "Alexanderplatz", line: "M4", destination: "Falkenberg", mode: .tram,
            walkingMinutes: 7, stopID: "900000001", stationCoordinate: GeoCoordinate(latitude: 52.55, longitude: 13.4),
            walkingState: .calculated)
        return Place(label: id == "home" ? "Home" : "Work", address: "\(id) address", bufferMinutes: 1, services: [service],
            locationID: id, coordinate: GeoCoordinate(latitude: latitude, longitude: 13.4))
    }

    private func board(now: Date) -> DepartureSnapshot {
        DepartureSnapshot(departures: [10, 15, 20, 25, 30].map {
            Departure(id: String($0), serviceID: "route", date: now.addingTimeInterval(Double($0) * 60))
        }, fetchedAt: now, isSample: false)
    }

    private struct Fixture {
        let suiteName: String
        let defaults: UserDefaults
        let store: LocationsStore
        let widgets: WidgetDataStore
        init() throws {
            suiteName = "LocationIntegrationTests.\(UUID().uuidString)"
            defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            store = LocationsStore(defaults: defaults)
            widgets = WidgetDataStore(defaults: defaults)
        }
        func cleanUp() { defaults.removePersistentDomain(forName: suiteName) }
    }
}

@MainActor private final class OriginWalkingProvider: WalkingTimeProviding {
    var calls = 0
    func walkingMinutes(from: GeoCoordinate, to: GeoCoordinate) async throws -> Int {
        calls += 1
        return from.latitude < 52.55 ? 7 : 17
    }
}

@MainActor private final class DelayedWalkingProvider: WalkingTimeProviding {
    private let onStarted: () -> Void
    private var continuation: CheckedContinuation<Int, Error>?
    init(onStarted: @escaping () -> Void) { self.onStarted = onStarted }
    func walkingMinutes(from: GeoCoordinate, to: GeoCoordinate) async throws -> Int {
        try await withCheckedThrowingContinuation {
            continuation = $0
            onStarted()
        }
    }
    func finish(minutes: Int) {
        continuation?.resume(returning: minutes)
        continuation = nil
    }
}
