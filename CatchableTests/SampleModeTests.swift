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
    @MainActor func testSampleAnnouncementsCanBeOpenedPerStation() async throws {
        let model = NowViewModel(provider: LiveDepartureProvider())
        let place = PlaceStore.sample
        await model.refresh(place: place, sampleMode: true)
        let german = model.notices(for: [place.services[0]])
        XCTAssertEqual(german.count, 1)
        XCTAssertTrue(try XCTUnwrap(german.first).text.contains("Beispielmeldung"))
        let english = model.notices(for: [place.services[1]])
        XCTAssertEqual(english.count, 1)
        XCTAssertTrue(try XCTUnwrap(english.first).text.contains("Sample announcement"))
        XCTAssertTrue(model.notices(for: [place.services[2]]).isEmpty)
        let empty = try await SampleDepartureProvider().fetchDepartures(for: [])
        XCTAssertTrue(empty.notices?.isEmpty == true)
    }
}
