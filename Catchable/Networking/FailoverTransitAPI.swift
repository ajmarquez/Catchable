import Foundation

/// VBB REST first, Transitous only after a failed request. Provider IDs never cross APIs.
struct FailoverTransitAPI: TransitAPI {
    var primary: any TransitAPI = TransportAPI()
    var fallback: any TransitAPI = TransitousAPI()

    func supportsStopID(_ id: String) -> Bool { StopReference(id) != nil }

    func searchStops(_ query: String) async throws -> [TransportStop] {
        do {
            return try await primary.searchStops(query).map { stop in
                // Preserve IFOPT identity for fallback, including non-Berlin VBB stops.
                let reference = "vbb:\(stop.id)|\(stop.ids?["ifopt"] ?? "")"
                return TransportStop(id: reference, name: stop.name)
            }
        } catch {
            try preserveCancellation(error)
            return try await fallback.searchStops(query)
        }
    }

    func board(stopID: String, minutes: Int) async throws -> TransportBoard {
        try await board(stopID: stopID, stationName: nil, minutes: minutes)
    }

    func board(stopID: String, stationName: String?, minutes: Int) async throws -> TransportBoard {
        guard let reference = StopReference(stopID) else { throw RoutingError.unsupportedStop }
        do {
            var board = try await primary.board(stopID: reference.vbbID, minutes: minutes)
            board.source = "VBB REST"
            return board
        } catch {
            try preserveCancellation(error)
            var transitousID = reference.transitousID
            if transitousID == nil, let stationName {
                // Legacy numeric IDs have no IFOPT metadata. Resolve by identity, never first result.
                let candidates = try await fallback.searchStops(stationName)
                transitousID = candidates.first { StopReference($0.id)?.vbbID == reference.vbbID }?.id
            }
            guard let transitousID else { throw RoutingError.missingFallbackIdentity }
            var board = try await fallback.board(stopID: transitousID, minutes: minutes)
            board.source = "Transitous (fallback)"
            return board
        }
    }

    func matches(_ item: TransportDeparture, service: SavedService) -> Bool {
        item.line?.name?.caseInsensitiveCompare(service.line) == .orderedSame &&
        item.mode == service.mode &&
        item.direction.map(Self.destinationKey) == Self.destinationKey(service.destination)
    }

    /// Normalize cosmetic provider differences while retaining the actual direction name.
    static func destinationKey(_ value: String) -> String {
        var text = value.lowercased().replacingOccurrences(of: "(berlin)", with: "")
            .replacingOccurrences(of: "straße", with: "strasse")
            .replacingOccurrences(of: "str.", with: "strasse")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["berlin, ", "s+u ", "u ", "s "] {
            if text.hasPrefix(prefix) { text.removeFirst(prefix.count) }
        }
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func preserveCancellation(_ error: Error) throws {
        if error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled {
            throw CancellationError()
        }
    }

    enum RoutingError: Error { case unsupportedStop, missingFallbackIdentity }
}

struct StopReference {
    let vbbID: String
    let transitousID: String?

    init?(_ value: String) {
        if value.hasPrefix("de-VBB_") {
            let identity = String(value.dropFirst("de-VBB_".count))
            let parts = identity.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count >= 3, Self.isVBBID(String(parts[2])) else { return nil }
            vbbID = String(parts[2])
            transitousID = value
        } else if value.hasPrefix("vbb:") {
            let parts = value.dropFirst(4).split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count == 2, Self.isVBBID(String(parts[0])) else { return nil }
            vbbID = String(parts[0])
            let identity = String(parts[1])
            if identity.isEmpty { transitousID = nil }
            else {
                let fields = identity.split(separator: ":", omittingEmptySubsequences: false)
                guard fields.count >= 3, fields[0] == "de", String(fields[2]) == vbbID else { return nil }
                transitousID = "de-VBB_" + identity
            }
        } else {
            guard Self.isVBBID(value) else { return nil }
            vbbID = value
            transitousID = nil
        }
    }

    private static func isVBBID(_ value: String) -> Bool {
        value.count == 9 && value.allSatisfy(\.isNumber)
    }
}
