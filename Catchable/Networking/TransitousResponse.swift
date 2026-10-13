import Foundation

struct TransitousLocation: Decodable {
    let type: String
    let id: String
    let name: String
    var lat: Double? = nil
    var lon: Double? = nil
}

struct TransitousBoard: Decodable {
    let stopTimes: [TransitousStopTime]
}

struct TransitousStopTime: Decodable {
    struct Place: Decodable {
        let departure: String?
        let scheduledDeparture: String?
        let cancelled: Bool?
    }
    let place: Place
    let mode: String
    let headsign: String?
    let routeId: String?
    let routeShortName: String?
    let displayName: String?
    let tripId: String?
    let realTime: Bool
    let cancelled: Bool?
    let tripCancelled: Bool?
    let pickupDropoffType: String?

    var normalized: TransportDeparture? {
        let product: String
        switch mode {
        case "TRAM": product = "tram"
        case "BUS": product = "bus"
        case "SUBWAY": product = "subway"
        case "SUBURBAN": product = "suburban"
        case "REGIONAL", "REGIONAL_FAST": product = "regional"
        default: return nil
        }
        guard pickupDropoffType != "NOT_ALLOWED" else { return nil }
        return TransportDeparture(tripId: tripId, direction: headsign,
            line: .init(id: routeId, name: routeShortName ?? displayName, product: product),
            when: place.departure, plannedWhen: place.scheduledDeparture,
            cancelled: cancelled == true || tripCancelled == true || place.cancelled == true,
            delay: nil, realtime: realTime)
    }
}
