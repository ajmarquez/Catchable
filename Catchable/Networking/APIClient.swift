import Foundation

/// Shared HTTP boundary for the future live provider. No API credentials in the app.
struct APIClient {
    enum APIError: Error { case invalidResponse, httpStatus(Int) }
    var session: URLSession = .shared
    var userAgent: String? = nil
    var timeoutInterval: TimeInterval = 25

    func get<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userAgent { request.setValue(userAgent, forHTTPHeaderField: "User-Agent") }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else { throw APIError.httpStatus(response.statusCode) }
        return try JSONDecoder().decode(type, from: data)
    }
}
