import XCTest
@testable import Catchable

final class WatchSyncReceiverTests: XCTestCase {
    func testOlderOrRepeatedPhoneStateCannotRestorePreviousLocation() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let receiver = WatchSyncReceiver(defaults: fixture.defaults)
        let home = PlaceStore.sample
        var work = home
        work.label = "Work"
        let new = try JSONEncoder().encode(WatchSyncPayload(place: work, snapshot: nil, sentAt: now))
        let old = try JSONEncoder().encode(WatchSyncPayload(place: home, snapshot: nil, sentAt: now.addingTimeInterval(-1)))
        XCTAssertTrue(try receiver.receive(new, now: now))
        XCTAssertFalse(try receiver.receive(old, now: now))
        XCTAssertFalse(try receiver.receive(new, now: now))
        XCTAssertEqual(fixture.store.loadPlace(), work)
    }

    func testNewPhoneMessageDoesNotReplaceFresherWatchBoard() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let place = PlaceStore.sample
        let receiver = WatchSyncReceiver(defaults: fixture.defaults)
        try receiver.receive(JSONEncoder().encode(WatchSyncPayload(place: place, snapshot: nil, sentAt: now)), now: now)
        let fresh = DepartureSnapshot(departures: [], fetchedAt: now, isSample: false, source: "Watch")
        try fixture.store.saveSnapshot(fresh, for: place, reloadTimelines: false)
        let older = DepartureSnapshot(departures: [], fetchedAt: now.addingTimeInterval(-60), isSample: false, source: "Phone")
        try receiver.receive(JSONEncoder().encode(WatchSyncPayload(place: place, snapshot: older, sentAt: now.addingTimeInterval(1))), now: now)
        XCTAssertEqual(fixture.store.loadSnapshot(for: place, now: now)?.source, "Watch")
        XCTAssertEqual(fixture.store.loadSnapshot(for: place, now: now)?.fetchedAt, now)
    }

    func testLocationSwitchClearsPreviousWatchBoardAndTransfersWalkingEstimate() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let home = PlaceStore.sample
        let receiver = WatchSyncReceiver(defaults: fixture.defaults)
        let homeBoard = DepartureSnapshot(departures: [], fetchedAt: now, isSample: false)
        try receiver.receive(JSONEncoder().encode(WatchSyncPayload(place: home, snapshot: homeBoard, sentAt: now)), now: now)
        var work = home
        work.label = "Work"
        work.services[0].walkingMinutes = 17
        work.services[0].walkingState = .calculated
        try receiver.receive(JSONEncoder().encode(WatchSyncPayload(place: work, snapshot: nil, sentAt: now.addingTimeInterval(1))), now: now)
        XCTAssertEqual(fixture.store.loadPlace(), work)
        XCTAssertEqual(fixture.store.loadPlace().services[0].walkingMinutes, 17)
        XCTAssertNil(fixture.store.loadSnapshot(for: home, now: now))
        XCTAssertNil(fixture.store.loadSnapshot(for: work, now: now))
    }

    private struct Fixture {
        let suite: String
        let defaults: UserDefaults
        let store: WidgetDataStore
        init() throws {
            suite = "WatchSyncReceiverTests.\(UUID().uuidString)"
            defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            store = WidgetDataStore(defaults: defaults)
        }
        func cleanup() { defaults.removePersistentDomain(forName: suite) }
    }
}
