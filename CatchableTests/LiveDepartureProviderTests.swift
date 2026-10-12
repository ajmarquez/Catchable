import XCTest
@testable import Catchable

final class FixtureURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let json = """
        {"departures":[
          {"tripId":"a","direction":"Target","line":{"id":"m10","name":"M10","product":"tram"},"when":"2030-01-01T12:10:00+01:00","delay":60},
          {"tripId":"b","direction":"Other","line":{"id":"m10","name":"M10","product":"tram"},"when":"2030-01-01T12:20:00+01:00"},
          {"tripId":"c","direction":"Target","line":{"id":"m10","name":"M10","product":"tram"},"when":null,"plannedWhen":"2030-01-01T12:30:00+01:00","cancelled":true},
          {"tripId":"d","direction":"Target","line":{"id":"m10","name":"M10","product":"tram"},"when":null,"plannedWhen":"2030-01-01T12:40:00+01:00"},
          {"tripId":"e","direction":"Target","line":{"id":"bus","name":"M10","product":"bus"},"when":"2030-01-01T12:50:00+01:00"}
        ]}
        """
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() { }
}

final class LiveDepartureProviderTests: XCTestCase {
    func testDirectionLineProductCancellationAndScheduledFallback() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let provider = LiveDepartureProvider(api: TransportAPI(client: APIClient(session: session)))
        let service = SavedService(id: "selected", station: "Stop", line: "M10", destination: "Target", mode: .tram, walkingMinutes: 5, stopID: "900000001", providerLineID: "m10")
        let snapshot = try await provider.fetchDepartures(for: [service])
        XCTAssertFalse(snapshot.isSample)
        XCTAssertEqual(snapshot.departures.count, 3)
        XCTAssertTrue(snapshot.departures[0].isRealtime)
        XCTAssertTrue(snapshot.departures[1].isCancelled)
        XCTAssertFalse(snapshot.departures[2].isRealtime)
        let now = ISO8601DateFormatter().date(from: "2030-01-01T12:00:00+01:00")!
        XCTAssertEqual(DepartureSelector().catchable(snapshot.departures, for: service, buffer: 1, now: now).count, 2)
    }

    func testLegacySavedServiceDecodesWithoutProviderIDs() throws {
        let data = Data(#"{"id":"old","station":"Stop","line":"M10","destination":"Target","mode":"Tram","walkingMinutes":5,"isSelected":true}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(SavedService.self, from: data).stopID)
    }
}
