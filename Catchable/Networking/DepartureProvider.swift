import Foundation

protocol DepartureProvider {
    func fetchDepartures(for services: [SavedService]) async throws -> DepartureSnapshot
}

/// Sample-only provider. Replace through dependency injection after verifying API access.
struct SampleDepartureProvider: DepartureProvider {
    func fetchDepartures(for services: [SavedService]) async throws -> DepartureSnapshot {
        try await Task.sleep(for: .milliseconds(250))
        let now = Date()
        let departures = services.flatMap { service in
            // Include an unreachable departure to exercise filtering in the app.
            [2, service.walkingMinutes + 3, service.walkingMinutes + 13, service.walkingMinutes + 23, service.walkingMinutes + 33].enumerated().map { index, offset in
                Departure(id: "\(service.id)-\(index)", serviceID: service.id,
                          date: now.addingTimeInterval(Double(offset) * 60))
            }
        }
        return DepartureSnapshot(departures: departures, fetchedAt: now, isSample: true)
    }
}
