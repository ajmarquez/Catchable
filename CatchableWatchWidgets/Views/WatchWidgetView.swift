import SwiftUI
import WidgetKit

struct WatchWidgetView: View {
    let entry: WidgetDepartureEntry
    @Environment(\.widgetFamily) private var family

    private var service: SavedService? { entry.place.services.first(where: \.isSelected) }
    private var departures: [Departure] { service.map { entry.catchableDepartures(for: $0) } ?? [] }
    private var status: String {
        if service == nil { return "Set up on iPhone" }
        if service?.walkingState == .pending { return "Set address on iPhone" }
        if service?.walkingState == .unavailable { return "Walking route unavailable" }
        if entry.snapshot == nil { return "Open to refresh" }
        return "No departures"
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline: inline
            case .accessoryCircular: circular
            default: rectangular
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var inline: some View {
        Group {
            if let service, let departure = departures.first {
                Text("\(service.line) · \(minutes(departure)) min · \(service.destination)")
            } else {
                Text("Catchable · \(status)")
            }
        }
    }

    private var circular: some View {
        VStack(spacing: 0) {
            Text(service?.line ?? "Catchable").font(.caption2.bold()).lineLimit(1).minimumScaleFactor(0.6)
                .widgetAccentable()
            if let departure = departures.first {
                Text("\(minutes(departure))").font(.system(size: 26, weight: .bold)).monospacedDigit()
                Text("min").font(.system(size: 9))
            } else {
                Image(systemName: service == nil ? "iphone" : "arrow.clockwise").font(.title3)
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let service {
                HStack(spacing: 4) {
                    Text(service.line).font(.caption.bold()).widgetAccentable()
                    Text(service.destination).font(.caption2.bold()).lineLimit(1)
                }
                if departures.isEmpty {
                    Text(status).font(.caption)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        ForEach(departures) { departure in
                            Text("\(minutes(departure))").font(.system(size: 24, weight: .bold)).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.65)
                                .accessibilityLabel("\(minutes(departure)) minutes")
                        }
                        Text("min").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text(footer(service)).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Text("CATCHABLE").font(.caption.bold()).widgetAccentable()
                Text(status).font(.caption2)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func minutes(_ departure: Departure) -> Int {
        max(0, Int(ceil(departure.date.timeIntervalSince(entry.date) / 60)))
    }

    private func footer(_ service: SavedService) -> String {
        if entry.snapshot?.isSample == true { return "Sample departures" }
        if entry.message != nil { return "Refresh unavailable · \(service.station)" }
        if departures.contains(where: { !$0.isRealtime }) { return "Scheduled · \(service.station)" }
        return "\(service.station) · \(service.walkingMinutes) min walk"
    }
}
