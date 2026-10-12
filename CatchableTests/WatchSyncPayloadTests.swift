import XCTest
@testable import Catchable

final class WatchSyncPayloadTests: XCTestCase {
    func testPayloadRoundTripsConfigurationAndLiveBoard() throws {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let departure = Departure(id: "one", serviceID: "bus-demo", date: date.addingTimeInterval(600))
        let board = DepartureSnapshot(departures: [departure], fetchedAt: date, isSample: false)
        let payload = WatchSyncPayload(place: PlaceStore.sample, snapshot: board, sentAt: date)
        let decoded = try WatchSyncPayload.decode(JSONEncoder().encode(payload))
        XCTAssertEqual(decoded.place, PlaceStore.sample)
        XCTAssertEqual(decoded.sentAt, date)
        XCTAssertEqual(decoded.snapshot?.departures, [departure])
        XCTAssertEqual(decoded.snapshot?.isSample, false)
    }

    func testSampleBoardIsNeverSentAndFutureProtocolIsRejected() throws {
        let board = DepartureSnapshot(departures: [], fetchedAt: Date(), isSample: true)
        let payload = WatchSyncPayload(place: PlaceStore.sample, snapshot: board)
        XCTAssertNil(payload.snapshot)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        json["version"] = WatchSyncPayload.currentVersion + 1
        XCTAssertThrowsError(try WatchSyncPayload.decode(JSONSerialization.data(withJSONObject: json)))
    }

    func testIncomingSampleBoardIsRejected() throws {
        let board = DepartureSnapshot(departures: [], fetchedAt: Date(), isSample: false)
        let payload = WatchSyncPayload(place: PlaceStore.sample, snapshot: board)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        var snapshot = try XCTUnwrap(json["snapshot"] as? [String: Any])
        snapshot["isSample"] = true
        json["snapshot"] = snapshot
        XCTAssertThrowsError(try WatchSyncPayload.decode(JSONSerialization.data(withJSONObject: json)))
    }
}
