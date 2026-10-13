import Foundation

struct GeoCoordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

enum WalkingState: String, Codable {
    case pending, calculated, unavailable
}

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
    var stopID: String? = nil
    var providerLineID: String? = nil
    var stationCoordinate: GeoCoordinate? = nil
    var walkingState: WalkingState? = nil
    var walkingUpdatedAt: Date? = nil
}

struct Place: Codable, Equatable, Identifiable {
    var label: String
    var address: String
    var bufferMinutes: Int
    var services: [SavedService]
    var locationID: String? = nil
    var coordinate: GeoCoordinate? = nil
    var id: String { locationID ?? "legacy-home" }
}

struct Departure: Identifiable, Codable, Equatable {
    var id: String
    var serviceID: String
    var date: Date
    var isCancelled = false
    var isRealtime = false
}

struct DepartureSnapshot: Codable {
    var departures: [Departure]
    var fetchedAt: Date
    var isSample: Bool
    var source: String? = nil
}
