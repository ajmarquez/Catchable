import Foundation

struct TransportStop: Decodable, Identifiable {
    let id: String
    let name: String
}

struct TransportBoard: Decodable {
    let departures: [TransportDeparture]
}

struct TransportDeparture: Decodable {
    struct Line: Decodable {
        let id: String?
        let name: String?
        let product: String?
    }
    let tripId: String?
    let direction: String?
    let line: Line?
    let when: String?
    let plannedWhen: String?
    let cancelled: Bool?
    let delay: Int?

    var date: Date? {
        guard let value = when ?? plannedWhen else { return nil }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter.date(from: value)
    }
    var mode: TransportMode? {
        switch line?.product {
        case "tram": return .tram
        case "bus": return .bus
        case "subway": return .subway
        case "suburban": return .suburban
        case "regional": return .regional
        default: return nil
        }
    }
}
