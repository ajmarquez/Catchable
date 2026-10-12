import Foundation

struct LiveDepartureProvider: DepartureProvider {
    var api: any TransitAPI = TransitousAPI()

    func fetchDepartures(for services: [SavedService]) async throws -> DepartureSnapshot {
        let configured = services.filter { service in
            service.stopID.map { api.supportsStopID($0) } ?? false
        }
        var departures: [Departure] = []
        // One request per station, even when several saved lines share it.
        let stopIDs = Set(configured.compactMap(\.stopID))
        for stopID in stopIDs.sorted() {
            try Task.checkCancellation()
            let board = try await api.board(stopID: stopID)
            for service in configured where service.stopID == stopID {
                departures += board.departures.enumerated().compactMap { index, item in
                    let sameLine = service.providerLineID.map { $0 == item.line?.id }
                        ?? (item.line?.name == service.line)
                    guard sameLine, item.mode == service.mode,
                          item.direction == service.destination, let date = item.date else { return nil }
                    return Departure(id: "\(service.id)-\(item.tripId ?? String(index))-\(date.timeIntervalSince1970)",
                                     serviceID: service.id, date: date,
                                     isCancelled: item.cancelled ?? false,
                                     isRealtime: item.realtime ?? (item.delay != nil))
                }
            }
        }
        return DepartureSnapshot(departures: departures, fetchedAt: Date(), isSample: false)
    }
}
