import Foundation

struct LiveDepartureProvider: DepartureProvider {
    var api: any TransitAPI = FailoverTransitAPI()

    func fetchDepartures(for services: [SavedService]) async throws -> DepartureSnapshot {
        let configured = services.filter { service in
            service.stopID.map { api.supportsStopID($0) } ?? false
        }
        var departures: [Departure] = []
        var sources = Set<String>()
        var notices: [ServiceNotice] = []
        var seenNotices = Set<String>()
        // One request per station, even when several saved lines share it.
        let stopIDs = Set(configured.compactMap(\.stopID))
        for stopID in stopIDs.sorted() {
            try Task.checkCancellation()
            let board = try await api.board(stopID: stopID, stationName: configured.first { $0.stopID == stopID }?.station, minutes: 120)
            if let source = board.source { sources.insert(source) }
            for service in configured where service.stopID == stopID {
                for item in board.departures where api.matches(item, service: service) {
                    for remark in item.remarks ?? [] {
                        guard let text = remark.noticeText else { continue }
                        let key = "\(service.id)|\(remark.id ?? text)|\(text)"
                        guard seenNotices.insert(key).inserted else { continue }
                        notices.append(ServiceNotice(id: key, serviceID: service.id, text: text, kind: remark.type ?? "hint"))
                    }
                }
                departures += board.departures.enumerated().compactMap { index, item in
                    guard api.matches(item, service: service), let date = item.date else { return nil }
                    return Departure(id: "\(service.id)-\(item.tripId ?? String(index))-\(date.timeIntervalSince1970)",
                                     serviceID: service.id, date: date,
                                     isCancelled: item.cancelled ?? false,
                                     isRealtime: item.realtime ?? (item.delay != nil))
                }
            }
        }
        return DepartureSnapshot(departures: departures, fetchedAt: Date(), isSample: false,
            source: sources.isEmpty ? nil : sources.sorted().joined(separator: " + "), notices: notices)
    }
}
