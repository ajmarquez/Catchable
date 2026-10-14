import Foundation

/// Third-party VBB/HAFAS wrapper; not an official VBB API contract.
struct TransportAPI: TransitAPI {
    var client = APIClient(userAgent: "Catchable/0.1 (https://github.com/ajmarquez/Catchable)", timeoutInterval: 8)
    let baseURL = URL(string: "https://v6.vbb.transport.rest")!

    func searchStops(_ query: String) async throws -> [TransportStop] {
        let url = try endpoint("locations", query: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "poi", value: "false"),
            URLQueryItem(name: "addresses", value: "false"),
            URLQueryItem(name: "results", value: "10")
        ])
        return try await client.get(url, as: [TransportStop].self)
    }

    func board(stopID: String, minutes: Int = 120) async throws -> TransportBoard {
        let url = try endpoint("stops/" + stopID + "/departures", query: [
            URLQueryItem(name: "duration", value: String(minutes)),
            URLQueryItem(name: "results", value: "300"),
            URLQueryItem(name: "remarks", value: "true")
        ])
        return try await client.get(url, as: TransportBoard.self)
    }

    private func endpoint(_ path: String, query: [URLQueryItem]) throws -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = query
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }
}
