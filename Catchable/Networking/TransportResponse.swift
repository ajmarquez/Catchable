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
    var remarks: [TransportRemark]? = nil

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

struct TransportRemark: Decodable {
    var id: String? = nil
    let type: String?
    var code: String? = nil
    var summary: String? = nil
    var text: String? = nil

    var noticeText: String? {
        guard let type, ["warning", "status", "hint"].contains(type) else { return nil }
        let routineCodes = ["OPERATOR", "FK", "BF", "CK", "PK", "FG"]
        if type == "hint", let code, routineCodes.contains(code.uppercased()) || code.hasPrefix("text.occup.") { return nil }
        let raw = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let chosen = raw?.isEmpty == false ? raw : summary
        guard var value = chosen else { return nil }
        value = value.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        for (entity, replacement) in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'")] {
            value = value.replacingOccurrences(of: entity, with: replacement)
        }
        value = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return value.isEmpty ? nil : value
    }
}

extension TransportRemark {
    private enum CodingKeys: String, CodingKey { case id, type, code, summary, text }

    init(from decoder: Decoder) throws {
        // Optional notice metadata must not make an otherwise valid departure board fail.
        guard let values = try? decoder.container(keyedBy: CodingKeys.self) else {
            id = nil; type = nil; code = nil; summary = nil; text = nil
            return
        }
        id = (try? values.decode(String.self, forKey: .id)) ??
            (try? values.decode(Int.self, forKey: .id)).map { String($0) }
        type = try? values.decode(String.self, forKey: .type)
        code = try? values.decode(String.self, forKey: .code)
        summary = try? values.decode(String.self, forKey: .summary)
        text = try? values.decode(String.self, forKey: .text)
    }
}
