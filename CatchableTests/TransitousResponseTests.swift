import XCTest
@testable import Catchable

final class TransitousResponseTests: XCTestCase {
    func testRealtimeScheduledFallbackAndCancellationMapping() throws {
        let data = Data(#"{"stopTimes":[{"place":{"departure":"2030-01-01T12:10:00Z","scheduledDeparture":"2030-01-01T12:09:00Z"},"mode":"TRAM","headsign":"Target","routeId":"de-VBB_route","routeShortName":"M10","realTime":true},{"place":{"scheduledDeparture":"2030-01-01T12:20:00Z","cancelled":true},"mode":"TRAM","headsign":"Target","routeId":"de-VBB_route","routeShortName":"M10","realTime":false}]}"#.utf8)
        let board = try JSONDecoder().decode(TransitousBoard.self, from: data)
        let first = try XCTUnwrap(board.stopTimes[0].normalized)
        XCTAssertEqual(first.mode, .tram)
        XCTAssertEqual(first.line?.id, "de-VBB_route")
        XCTAssertEqual(first.realtime, true)
        XCTAssertEqual(first.date, ISO8601DateFormatter().date(from: "2030-01-01T12:10:00Z"))
        let second = try XCTUnwrap(board.stopTimes[1].normalized)
        XCTAssertEqual(second.realtime, false)
        XCTAssertEqual(second.cancelled, true)
        XCTAssertNotNil(second.date)
    }

    func testProviderRejectsLegacyIDs() {
        XCTAssertFalse(TransitousAPI().supportsStopID("900120516"))
        XCTAssertTrue(TransitousAPI().supportsStopID("de-VBB_de:11000:900120516"))
    }
}
