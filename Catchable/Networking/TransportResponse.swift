import Foundation

struct TransportStop: Decodable, Identifiable {
    struct Location: Decodable {
        let latitude: Double
        let longitude: Double
    }
    let id: String
    let name: String
    var ids: [String: String]? = nil
    var location: Location? = nil
    var lat: Double? = nil
    var lon: Double? = nil
    var coordinate: GeoCoordinate? {
        let result: GeoCoordinate?
        if let location { result = GeoCoordinate(latitude: location.latitude, longitude: location.longitude) }
        else if let lat, let lon { result = GeoCoordinate(latitude: lat, longitude: lon) }
        else { result = nil }
        return result?.isValid == true ? result : nil
    }
}

struct TransportBoard: Decodable {
    let departures: [TransportDeparture]
    var source: String? = nil
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
    var realtime: Bool? = nil

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
