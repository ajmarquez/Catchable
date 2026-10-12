import XCTest
@testable import Catchable

final class WidgetDataStoreTests: XCTestCase {
    func testExistingPlaceMigratesOnceAndSharedEditsTakePriority() throws {
        let sharedSuite = "WidgetShared.\(UUID().uuidString)"
        let legacySuite = "WidgetLegacy.\(UUID().uuidString)"
        let shared = try XCTUnwrap(UserDefaults(suiteName: sharedSuite))
        let legacy = try XCTUnwrap(UserDefaults(suiteName: legacySuite))
        defer {
            shared.removePersistentDomain(forName: sharedSuite)
            legacy.removePersistentDomain(forName: legacySuite)
        }
        try legacy.set(JSONEncoder().encode(PlaceStore.sample), forKey: "catchable.home.v1")
        let store = WidgetDataStore(defaults: shared, legacy: legacy)
        XCTAssertEqual(store.loadPlace(), PlaceStore.sample)
        var edited = PlaceStore.sample
        edited.label = "Work"
        try store.savePlace(edited)
        XCTAssertEqual(store.loadPlace(), edited)
        XCTAssertEqual(WidgetDataStore(defaults: shared).loadPlace(), edited)
    }

    func testCacheRejectsStaleDataSampleDataAndChangedPlace() throws {
        let suite = "WidgetDataStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WidgetDataStore(defaults: defaults)
        let place = PlaceStore.sample
        try store.savePlace(place)
        let now = Date()
        let live = DepartureSnapshot(departures: [], fetchedAt: now, isSample: false)
        try store.saveSnapshot(live, for: place, reloadTimelines: false)
        XCTAssertNotNil(store.loadSnapshot(for: place, now: now.addingTimeInterval(899)))
        XCTAssertNil(store.loadSnapshot(for: place, now: now.addingTimeInterval(900)))
        var changed = place
        changed.bufferMinutes += 1
        try store.savePlace(changed)
        XCTAssertNil(store.loadSnapshot(for: changed, now: now))
        // An in-flight response for the previous configuration cannot restore the cache.
        try store.saveSnapshot(live, for: place, reloadTimelines: false)
        XCTAssertNil(store.loadSnapshot(for: place, now: now))
        let sample = DepartureSnapshot(departures: [], fetchedAt: now, isSample: true)
        try store.saveSnapshot(sample, for: changed, reloadTimelines: false)
        XCTAssertNil(store.loadSnapshot(for: changed, now: now))
    }
}
