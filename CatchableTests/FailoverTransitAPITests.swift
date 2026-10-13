import XCTest
@testable import Catchable

final class FailoverTransitAPITests: XCTestCase {
    func testPrimarySearchPreservesFallbackIdentityAndPrimaryBoardIsPreferred() async throws {
        let primary = Stub()
        let fallback = Stub()
        primary.stops = [TransportStop(id: "900120516", name: "Bersarinplatz", ids: ["ifopt": "de:11000:900120516"])]
        let api = FailoverTransitAPI(primary: primary, fallback: fallback)
        let stops = try await api.searchStops("Bers")
        XCTAssertEqual(stops.first?.id, "vbb:900120516|de:11000:900120516")
        let board = try await api.board(stopID: XCTUnwrap(stops.first).id)
        XCTAssertEqual(board.source, "VBB REST")
        XCTAssertEqual(primary.boards, ["900120516"])
        XCTAssertTrue(fallback.boards.isEmpty)
        XCTAssertTrue(fallback.queries.isEmpty)
    }

    func testFailedBoardUsesTransitousIDIncludingPlatformForExistingSavedService() async throws {
        let primary = Stub(error: URLError(.timedOut))
        let fallback = Stub()
        let api = FailoverTransitAPI(primary: primary, fallback: fallback)
        let id = "de-VBB_de:11000:900120816::1"
        let board = try await api.board(stopID: id)
        XCTAssertEqual(primary.boards, ["900120816"])
        XCTAssertEqual(fallback.boards, [id])
        XCTAssertEqual(board.source, "Transitous (fallback)")
    }

    func testFailedSearchUsesFallbackButSuccessfulEmptySearchDoesNot() async throws {
        let primary = Stub(error: URLError(.badServerResponse))
        let fallback = Stub()
        fallback.stops = [TransportStop(id: "de-VBB_de:11000:900120516", name: "Bersarinplatz")]
        let api = FailoverTransitAPI(primary: primary, fallback: fallback)
        let stops = try await api.searchStops("Bers")
        XCTAssertEqual(stops.first?.id, fallback.stops.first?.id)
        primary.error = nil
        let empty = try await api.searchStops("Nothing")
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(fallback.queries, ["Bers"])
    }

    func testCancellationDoesNotStartFallback() async throws {
        let primary = Stub(error: URLError(.cancelled))
        let fallback = Stub()
        let api = FailoverTransitAPI(primary: primary, fallback: fallback)
        do { _ = try await api.searchStops("Bers"); XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        do { _ = try await api.board(stopID: "de-VBB_de:11000:900120516"); XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(fallback.queries.isEmpty)
        XCTAssertTrue(fallback.boards.isEmpty)
    }

    func testLegacyStopResolutionRequiresMatchingIdentityNotFirstSearchResult() async throws {
        let primary = Stub(error: URLError(.timedOut))
        let fallback = Stub()
        fallback.stops = [
            TransportStop(id: "de-VBB_de:11000:900100020", name: "Wrong stop"),
            TransportStop(id: "de-VBB_de:11000:900120516", name: "Bersarinplatz")
        ]
        let api = FailoverTransitAPI(primary: primary, fallback: fallback)
        _ = try await api.board(stopID: "900120516", stationName: "Bersarinplatz", minutes: 120)
        XCTAssertEqual(fallback.boards, ["de-VBB_de:11000:900120516"])
        fallback.stops = []
        do {
            _ = try await api.board(stopID: "900120516", stationName: "Bersarinplatz", minutes: 120)
            XCTFail("Must not guess an unrelated stop")
        } catch { XCTAssertTrue(error is FailoverTransitAPI.RoutingError) }
        XCTAssertEqual(fallback.boards.count, 1)
    }

    func testSavedTransitousServiceMatchesPrimaryLineAndSameDirectionOnly() async throws {
        let primary = Stub()
        let fallback = Stub()
        let now = Date()
        let departure = TransportDeparture(tripId: "trip", direction: "S+U Warschauer Str.",
            line: .init(id: "vbb-route", name: "M10", product: "tram"),
            when: ISO8601DateFormatter().string(from: now.addingTimeInterval(1200)),
            plannedWhen: nil, cancelled: false, delay: 60)
        primary.departures = [departure]
        let service = SavedService(id: "saved", station: "Bersarinplatz", line: "M10",
            destination: "S+U Warschauer Str. (Berlin)", mode: .tram, walkingMinutes: 5,
            stopID: "de-VBB_de:11000:900120516", providerLineID: "transitous-route")
        let api = FailoverTransitAPI(primary: primary, fallback: fallback)
        let result = try await LiveDepartureProvider(api: api).fetchDepartures(for: [service])
        XCTAssertEqual(result.departures.count, 1)
        XCTAssertEqual(result.source, "VBB REST")
        var opposite = service
        opposite.destination = "S+U Hauptbahnhof (Berlin)"
        XCTAssertFalse(api.matches(departure, service: opposite))
    }

    func testStopReferenceRejectsUnsupportedIDsAndPreservesNonBerlinIFOPT() {
        XCTAssertNil(StopReference("demo"))
        XCTAssertNil(StopReference("de-DELFI_de:11000:900120516"))
        XCTAssertNil(StopReference("vbb:900120516|de:11000:900100020"))
        XCTAssertEqual(StopReference("vbb:900230999|de:12054:900230999")?.transitousID,
                       "de-VBB_de:12054:900230999")
    }

    private final class Stub: TransitAPI {
        var error: Error?
        var stops: [TransportStop] = []
        var departures: [TransportDeparture] = []
        var queries: [String] = []
        var boards: [String] = []
        init(error: Error? = nil) { self.error = error }
        func searchStops(_ query: String) async throws -> [TransportStop] {
            queries.append(query)
            if let error { throw error }
            return stops
        }
        func board(stopID: String, minutes: Int) async throws -> TransportBoard {
            boards.append(stopID)
            if let error { throw error }
            return TransportBoard(departures: departures)
        }
    }
}
