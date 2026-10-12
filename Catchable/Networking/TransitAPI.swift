import Foundation

protocol TransitAPI {
    func supportsStopID(_ id: String) -> Bool
    func searchStops(_ query: String) async throws -> [TransportStop]
    func board(stopID: String, minutes: Int) async throws -> TransportBoard
}

extension TransitAPI {
    func supportsStopID(_ id: String) -> Bool { true }
    func board(stopID: String) async throws -> TransportBoard {
        try await board(stopID: stopID, minutes: 120)
    }
}
