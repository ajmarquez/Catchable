import Foundation

protocol TransitAPI {
    func supportsStopID(_ id: String) -> Bool
    func searchStops(_ query: String) async throws -> [TransportStop]
    func board(stopID: String, minutes: Int) async throws -> TransportBoard
    func board(stopID: String, stationName: String?, minutes: Int) async throws -> TransportBoard
    func matches(_ departure: TransportDeparture, service: SavedService) -> Bool
}

extension TransitAPI {
    func board(stopID: String, stationName: String?, minutes: Int) async throws -> TransportBoard {
        try await board(stopID: stopID, minutes: minutes)
    }
    func matches(_ item: TransportDeparture, service: SavedService) -> Bool {
        let sameLine = service.providerLineID.map { $0 == item.line?.id } ?? (item.line?.name == service.line)
        return sameLine && item.mode == service.mode && item.direction == service.destination
    }
    func supportsStopID(_ id: String) -> Bool { true }
    func board(stopID: String) async throws -> TransportBoard {
        try await board(stopID: stopID, minutes: 120)
    }
}
