import XCTest
@testable import Catchable

final class StationCoordinateTests: XCTestCase {
    func testVBBCoordinatesDecodeAndInvalidCoordinatesAreRejected() throws {
        let data = Data(#"{"id":"900120516","name":"Bersarinplatz","location":{"latitude":52.519342,"longitude":13.452564}}"#.utf8)
        let stop = try JSONDecoder().decode(TransportStop.self, from: data)
        XCTAssertEqual(stop.coordinate, GeoCoordinate(latitude: 52.519342, longitude: 13.452564))
        XCTAssertNil(TransportStop(id: "bad", name: "Invalid", lat: 999, lon: 13).coordinate)
    }

    func testTransitousCoordinatesDecodeAndPendingWalkIsNotCatchable() throws {
        let data = Data(#"{"type":"STOP","id":"de-VBB_de:11000:900120516","name":"Bersarinplatz","lat":52.519342,"lon":13.452564}"#.utf8)
        let stop = try JSONDecoder().decode(TransitousLocation.self, from: data)
        XCTAssertEqual(stop.lat, 52.519342)
        XCTAssertEqual(stop.lon, 13.452564)
        var service = PlaceStore.sample.services[0]
        service.walkingState = .pending
        let now = Date()
        let departures = [Departure(id: "future", serviceID: service.id, date: now.addingTimeInterval(3600))]
        XCTAssertTrue(DepartureSelector().catchable(departures, for: service, buffer: 1, now: now).isEmpty)
    }
}
