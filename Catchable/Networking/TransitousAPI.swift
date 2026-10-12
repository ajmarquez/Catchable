import Foundation

/// Prototype access under https://transitous.org/api/ usage policy.
struct TransitousAPI: TransitAPI {
    var client = APIClient(userAgent: "Catchable/0.1 (prototype; https://ajmarquez.com)")
    private let baseURL = URL(string: "https://api.transitous.org/api")!

    func supportsStopID(_ id: String) -> Bool { id.hasPrefix("de-VBB_") }

    func searchStops(_ query: String) async throws -> [TransportStop] {
        let url = try endpoint("v1/geocode", query: [
            URLQueryItem(name: "text", value: query),
            URLQueryItem(name: "type", value: "STOP"),
            URLQueryItem(name: "place", value: "52.52,13.405"),
            URLQueryItem(name: "numResults", value: "10")
        ])
        let locations = try await client.get(url, as: [TransitousLocation].self)
        // Restrict this first iteration to VBB stops, avoiding duplicate national feeds.
        return locations.filter { $0.type == "STOP" && $0.id.hasPrefix("de-VBB_") }
            .map { TransportStop(id: $0.id, name: $0.name) }
    }

    func board(stopID: String, minutes: Int = 120) async throws -> TransportBoard {
        let now = Date()
        let url = try endpoint("v6/stoptimes", query: [
            URLQueryItem(name: "stopId", value: stopID),
            URLQueryItem(name: "arriveBy", value: "false"),
            URLQueryItem(name: "time", value: ISO8601DateFormatter().string(from: now)),
            URLQueryItem(name: "window", value: String(minutes * 60)),
            URLQueryItem(name: "n", value: "1")
        ])
        let board = try await client.get(url, as: TransitousBoard.self)
        let end = now.addingTimeInterval(Double(minutes * 60))
        return TransportBoard(departures: board.stopTimes.compactMap(\.normalized).filter {
            guard let date = $0.date else { return false }
            return date >= now && date <= end
        })
    }

    private func endpoint(_ path: String, query: [URLQueryItem]) throws -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }
}
