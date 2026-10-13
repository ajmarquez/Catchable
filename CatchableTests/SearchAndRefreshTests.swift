import XCTest
@testable import Catchable

final class SearchAndRefreshTests: XCTestCase {
    @MainActor func testSearchStartsAtThreeCharactersAndRequestsEveryEdit() async {
        let api = RecordingSearchAPI()
        let model = ServiceSearchViewModel(api: api)
        for query in ["", "a", "ab", "abc", "abcd", "abcde"] {
            model.query = query
            await model.search()
        }
        let queries = await api.queries
        XCTAssertEqual(queries, ["abc", "abcd", "abcde"])
    }

    @MainActor func testDelayedSearchCannotOverwriteNewerResults() async {
        let started = expectation(description: "Old search suspended")
        let finished = expectation(description: "Old search finished")
        let api = DelayedSearchAPI(started: started)
        let model = ServiceSearchViewModel(api: api)
        model.query = "old"
        Task { await model.search(); finished.fulfill() }
        await fulfillment(of: [started], timeout: 2)
        model.query = "new"
        await model.search()
        await api.completeOld()
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertEqual(model.stops.map(\.id), ["new"])
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
    }

    @MainActor func testOldPlaceResponseCannotReplaceLatestSnapshotOrError() async {
        for (oldFails, newFails) in [(false, false), (true, false), (false, true), (true, true)] {
            let started = expectation(description: "Old refresh suspended \(oldFails)")
            let finished = expectation(description: "Old refresh finished \(oldFails)")
            let provider = DelayedDepartureProvider(started: started, newestFails: newFails)
            let model = NowViewModel(provider: provider)
            var old = PlaceStore.sample
            old.services = [old.services[0]]
            old.services[0].id = "old"
            var newest = old
            newest.label = "Work"
            newest.services[0].id = "new"
            Task { await model.refresh(place: old); finished.fulfill() }
            await fulfillment(of: [started], timeout: 2)
            await model.refresh(place: newest)
            await provider.completeOld(failing: oldFails)
            await fulfillment(of: [finished], timeout: 2)
            if newFails {
                XCTAssertNil(model.snapshot)
                XCTAssertNotNil(model.errorMessage)
            } else {
                XCTAssertEqual(model.snapshot?.departures.map(\.serviceID), ["new"])
                XCTAssertNil(model.errorMessage)
            }
            XCTAssertFalse(model.isLoading)
        }
    }

    @MainActor func testSampleRefreshSkipsLiveProviderAndCannotReplaceLiveCache() async throws {
        let provider = CountingDepartureProvider()
        let model = NowViewModel(provider: provider)
        let place = PlaceStore.sample
        await model.refresh(place: place, sampleMode: true)
        let calls = await provider.calls
        XCTAssertEqual(calls, 0)
        let sample = try XCTUnwrap(model.snapshot)
        XCTAssertTrue(sample.isSample)
        let suite = "SearchAndRefreshTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = WidgetDataStore(defaults: defaults)
        try store.savePlace(place)
        let live = DepartureSnapshot(departures: [], fetchedAt: Date(), isSample: false, source: "sentinel")
        try store.saveSnapshot(live, for: place, reloadTimelines: false)
        try store.saveSnapshot(sample, for: place, reloadTimelines: false)
        XCTAssertEqual(store.loadSnapshot(for: place)?.source, "sentinel")
    }
}

private actor RecordingSearchAPI: TransitAPI {
    var queries: [String] = []
    func searchStops(_ query: String) async throws -> [TransportStop] {
        queries.append(query)
        return []
    }
    func board(stopID: String, minutes: Int) async throws -> TransportBoard { throw TestFailure.expected }
}

private actor DelayedSearchAPI: TransitAPI {
    let started: XCTestExpectation
    var pending: CheckedContinuation<[TransportStop], Never>?
    init(started: XCTestExpectation) { self.started = started }
    func searchStops(_ query: String) async throws -> [TransportStop] {
        if query == "old" {
            return await withCheckedContinuation { continuation in
                pending = continuation
                started.fulfill()
            }
        }
        return [TransportStop(id: query, name: query)]
    }
    func completeOld() {
        pending?.resume(returning: [TransportStop(id: "old", name: "Old")])
        pending = nil
    }
    func board(stopID: String, minutes: Int) async throws -> TransportBoard { throw TestFailure.expected }
}

private actor DelayedDepartureProvider: DepartureProvider {
    let started: XCTestExpectation
    var pending: CheckedContinuation<DepartureSnapshot, Error>?
    let newestFails: Bool
    init(started: XCTestExpectation, newestFails: Bool) {
        self.started = started
        self.newestFails = newestFails
    }
    func fetchDepartures(for services: [SavedService]) async throws -> DepartureSnapshot {
        if services.first?.id == "old" {
            return try await withCheckedThrowingContinuation { continuation in
                pending = continuation
                started.fulfill()
            }
        }
        if newestFails { throw TestFailure.expected }
        return Self.snapshot("new")
    }
    func completeOld(failing: Bool) {
        if failing { pending?.resume(throwing: TestFailure.expected) }
        else { pending?.resume(returning: Self.snapshot("old")) }
        pending = nil
    }
    private static func snapshot(_ id: String) -> DepartureSnapshot {
        DepartureSnapshot(departures: [Departure(id: id, serviceID: id, date: Date().addingTimeInterval(600))],
                          fetchedAt: Date(), isSample: false)
    }
}

private actor CountingDepartureProvider: DepartureProvider {
    var calls = 0
    func fetchDepartures(for services: [SavedService]) async throws -> DepartureSnapshot {
        calls += 1
        throw TestFailure.expected
    }
}

private enum TestFailure: Error { case expected }
