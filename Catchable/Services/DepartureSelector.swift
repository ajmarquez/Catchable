import Foundation

struct DepartureSelector {
    func catchable(_ departures: [Departure], for service: SavedService, buffer: Int, now: Date) -> [Departure] {
        let threshold = now.addingTimeInterval(Double(service.walkingMinutes + buffer) * 60)
        return Array(departures.filter {
            $0.serviceID == service.id && !$0.isCancelled && $0.date >= threshold
        }.sorted { $0.date < $1.date }.prefix(3))
    }
}
