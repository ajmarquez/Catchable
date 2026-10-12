import Foundation
import Observation

struct ServiceOption: Identifiable {
    let id: String
    let lineID: String?
    let line: String
    let destination: String
    let mode: TransportMode
}

@MainActor @Observable final class ServiceSearchViewModel {
    var query = ""
    var stops: [TransportStop] = []
    var selectedStop: TransportStop?
    var options: [ServiceOption] = []
    var isLoading = false
    var errorMessage: String?
    private let api = TransportAPI()
    private var generation = 0

    func search() async {
        generation += 1
        let request = generation
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { stops = []; isLoading = false; return }
        isLoading = true
        selectedStop = nil
        options = []
        errorMessage = nil
        defer { if generation == request { isLoading = false } }
        do {
            let result = try await api.searchStops(text)
            guard request == generation else { return }
            stops = result
        } catch {
            if request == generation { errorMessage = "Stop search failed. Check your connection and try again." }
        }
    }

    func select(_ stop: TransportStop) async {
        generation += 1
        let request = generation
        selectedStop = stop
        options = []
        errorMessage = nil
        isLoading = true
        defer { if generation == request { isLoading = false } }
        do {
            let board = try await api.board(stopID: stop.id)
            guard request == generation else { return }
            var seen = Set<String>()
            options = board.departures.compactMap { item in
                guard let line = item.line?.name, let destination = item.direction,
                      let mode = item.mode, item.cancelled != true else { return nil }
                let key = "\(item.line?.id ?? line)|\(mode.rawValue)|\(destination)"
                guard seen.insert(key).inserted else { return nil }
                return ServiceOption(id: key, lineID: item.line?.id, line: line, destination: destination, mode: mode)
            }.sorted { ($0.line, $0.destination) < ($1.line, $1.destination) }
        } catch {
            if request == generation { errorMessage = "Could not load this station’s services. Try again." }
        }
    }
}
