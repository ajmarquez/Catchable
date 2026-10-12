import Foundation

/// Shared HTTP boundary for the future live provider. No API credentials in the app.
struct APIClient {
    enum APIError: Error { case invalidResponse, httpStatus(Int) }
    var session: URLSession = .shared

    func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw APIError.httpStatus(response.statusCode) }
        return try JSONDecoder().decode(type, from: data)
    }
}
