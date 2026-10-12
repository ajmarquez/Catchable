import XCTest
@testable import Catchable

final class DepartureSelectorTests: XCTestCase {
    func testFiltersCancelledUnreachableAndOtherServicesThenSortsAndLimits() {
        let now = Date(timeIntervalSince1970: 0)
        let service = PlaceStore.sample.services[0]
        func departure(_ minutes: Double, cancelled: Bool = false, serviceID: String? = nil) -> Departure {
            Departure(id: UUID().uuidString, serviceID: serviceID ?? service.id, date: now.addingTimeInterval(minutes * 60), isCancelled: cancelled)
        }
        let input = [departure(30), departure(3), departure(6), departure(9, cancelled: true), departure(8, serviceID: "other"), departure(20), departure(10)]
        let result = DepartureSelector().catchable(input, for: service, buffer: 1, now: now)
        XCTAssertEqual(result.map { $0.date.timeIntervalSince(now) / 60 }, [6, 10, 20])
    }
    func testPersistenceRoundTrip() throws {
        let suite = "CatchableTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PlaceStore(defaults: defaults)
        var place = store.load()
        place.label = "My Home"
        place.services[0].isSelected = false
        try store.save(place)
        XCTAssertEqual(store.load(), place)
    }
}
