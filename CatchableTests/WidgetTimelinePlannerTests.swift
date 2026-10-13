import XCTest
@testable import Catchable

final class WidgetTimelinePlannerTests: XCTestCase {
    func testCachedBoardExpiresAtFifteenMinutesEvenWhenRefreshIsDelayed() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let board = DepartureSnapshot(departures: [], fetchedAt: now, isSample: false)
        let frames = WidgetTimelinePlanner().frames(snapshot: board, message: nil, now: now)
        XCTAssertNotNil(frames.first?.snapshot)
        XCTAssertNotNil(frames.first { $0.date == now.addingTimeInterval(14 * 60) }?.snapshot)
        let expired = try XCTUnwrap(frames.first { $0.date == now.addingTimeInterval(15 * 60) })
        XCTAssertNil(expired.snapshot)
        XCTAssertEqual(expired.message, "Open Catchable to refresh")
        XCTAssertTrue(frames.filter { $0.date >= expired.date }.allSatisfy { $0.snapshot == nil })
    }

    func testFailedRefreshPreservesFreshCacheAndItsFailureMessageUntilExpiry() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let board = DepartureSnapshot(departures: [], fetchedAt: now.addingTimeInterval(-14 * 60), isSample: false)
        let frames = WidgetTimelinePlanner().frames(snapshot: board, message: "Unable to refresh", now: now)
        XCTAssertNotNil(frames.first?.snapshot)
        XCTAssertEqual(frames.first?.message, "Unable to refresh")
        let next = try XCTUnwrap(frames.first { $0.date > now })
        XCTAssertNil(next.snapshot)
        XCTAssertEqual(next.message, "Unable to refresh")
    }

    func testFutureDatedBoardIsNotPresentedAsFresh() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let board = DepartureSnapshot(departures: [], fetchedAt: now.addingTimeInterval(3600), isSample: false)
        XCTAssertNil(WidgetTimelinePlanner().frames(snapshot: board, message: nil, now: now).first?.snapshot)
    }

    func testMinuteEntriesRemoveDepartureThatIsNoLongerReachable() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let service = PlaceStore.sample.services[0] // 5 minutes + 1 minute buffer.
        let first = Departure(id: "first", serviceID: service.id, date: now.addingTimeInterval(6 * 60))
        let later = Departure(id: "later", serviceID: service.id, date: now.addingTimeInterval(10 * 60))
        let board = DepartureSnapshot(departures: [first, later], fetchedAt: now, isSample: false)
        let frames = WidgetTimelinePlanner().frames(snapshot: board, message: nil, now: now)
        let initial = try XCTUnwrap(frames.first)
        let next = try XCTUnwrap(frames.first { $0.date > now })
        let selector = DepartureSelector()
        XCTAssertEqual(selector.catchable(initial.snapshot?.departures ?? [], for: service, buffer: 1, now: initial.date).map(\.id), ["first", "later"])
        XCTAssertEqual(selector.catchable(next.snapshot?.departures ?? [], for: service, buffer: 1, now: next.date).map(\.id), ["later"])
    }
}
