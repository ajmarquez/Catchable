import Foundation

/// A self-contained copy: App Group containers are local to each device.
struct WatchSyncPayload: Codable {
    static let currentVersion = 1
    let version: Int
    let sentAt: Date
    let place: Place
    let snapshot: DepartureSnapshot?

    init(place: Place, snapshot: DepartureSnapshot?, sentAt: Date = Date()) {
        version = Self.currentVersion
        self.sentAt = sentAt
        self.place = place
        self.snapshot = snapshot?.isSample == false ? snapshot : nil
    }

    static func decode(_ data: Data) throws -> WatchSyncPayload {
        let payload = try JSONDecoder().decode(Self.self, from: data)
        guard payload.version == currentVersion else { throw DecodingError.unsupportedVersion }
        guard payload.snapshot?.isSample != true else { throw DecodingError.sampleData }
        return payload
    }

    enum DecodingError: Error {
        case unsupportedVersion
        case sampleData
    }
}
