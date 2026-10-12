import XCTest
@testable import Catchable

final class SampleModeTests: XCTestCase {
    @MainActor func testSampleModeLoadsThreeCatchableDeparturesForEveryStation() async {
        let model = NowViewModel(provider: LiveDepartureProvider())
        let place = PlaceStore.sample
        await model.refresh(place: place, sampleMode: true)
        XCTAssertTrue(model.snapshot?.isSample == true)
        XCTAssertNil(model.errorMessage)
        for service in place.services {
            XCTAssertEqual(model.departures(for: service, place: place, now: Date()).count, 3)
        }
    }
}
