import XCTest
@testable import Catchable

final class LocationValidationTests: XCTestCase {
    func testLocationRequiresLabelAddressAndValidCoordinate() {
        let point = GeoCoordinate(latitude: 52.52, longitude: 13.41)
        XCTAssertTrue(LocationValidation.isValid(label: "Home", address: "Alexanderplatz 1, Berlin", coordinate: point))
        XCTAssertFalse(LocationValidation.isValid(label: "  ", address: "Address", coordinate: point))
        XCTAssertFalse(LocationValidation.isValid(label: "Home", address: nil, coordinate: point))
        XCTAssertFalse(LocationValidation.isValid(label: "Home", address: " \n", coordinate: point))
        XCTAssertFalse(LocationValidation.isValid(label: "Home", address: "Address", coordinate: nil))
        XCTAssertFalse(LocationValidation.isValid(label: "Home", address: "Address", coordinate: GeoCoordinate(latitude: .nan, longitude: 13)))
        XCTAssertFalse(LocationValidation.isValid(label: "Home", address: "Address", coordinate: GeoCoordinate(latitude: 91, longitude: 13)))
    }

    @MainActor func testInvalidNewLocationDoesNotPersist() throws {
        let suite = "LocationValidationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocationsStore(defaults: defaults)
        let vm = PlacesViewModel(locationsStore: store)
        vm.saveLocation(Place(label: "Home", address: "Typed but not selected", bufferMinutes: 1, services: []))
        XCTAssertTrue(vm.locations.isEmpty)
        XCTAssertTrue(store.load().locations.isEmpty)
        XCTAssertNotNil(vm.saveError)
    }
}
