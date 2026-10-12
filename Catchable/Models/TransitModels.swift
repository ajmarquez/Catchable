import Foundation

enum TransportMode: String, Codable, CaseIterable, Identifiable {
    case tram = "Tram", bus = "Bus", subway = "U-Bahn", suburban = "S-Bahn", regional = "Regional"
    var id: String { rawValue }
}

struct SavedService: Identifiable, Codable, Equatable {
    var id: String
    var station: String
    var line: String
    var destination: String
    var mode: TransportMode
    var walkingMinutes: Int
    var isSelected = true
}

struct Place: Codable, Equatable {
    var label: String
    var address: String
    var bufferMinutes: Int
    var services: [SavedService]
}

struct Departure: Identifiable, Equatable {
    var id: String
    var serviceID: String
    var date: Date
    var isCancelled = false
}

struct DepartureSnapshot {
    var departures: [Departure]
    var fetchedAt: Date
    var isSample: Bool
}
