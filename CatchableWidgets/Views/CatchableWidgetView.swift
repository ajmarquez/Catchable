import SwiftUI
import WidgetKit

struct CatchableWidgetView: View {
    let entry: WidgetDepartureEntry
    let style: CatchableWidgetStyle
    @Environment(\.widgetFamily) private var family

    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }
    private var services: [SavedService] {
        let count = small ? 1 : large ? (style == .next ? 4 : 3) : (style == .badges ? 1 : 2)
        return Array(entry.place.services.filter(\.isSelected).prefix(count))
    }
    private var stale: Bool {
        guard let snapshot = entry.snapshot else { return false }
        return !snapshot.isSample && entry.date.timeIntervalSince(snapshot.fetchedAt) >= WidgetDataStore.maximumAge
    }

    var body: some View {
        VStack(alignment: .leading, spacing: small ? 6 : large ? 9 : 5) {
            Text("Departing from \(entry.place.label)")
                .font(.system(size: small ? 11 : 13, weight: .bold))
                .lineLimit(1)
            if services.isEmpty {
                emptyState("Choose your stations", detail: "Open Catchable to set up your place.")
            } else if stale {
                emptyState("Refresh Catchable", detail: "Departure data needs an update.")
            } else if entry.snapshot == nil {
                emptyState("Departures unavailable", detail: entry.message ?? "Open Catchable to refresh.")
            } else {
                switch style {
                case .badges: badgeLayout
                case .timetable: timetableLayout
                case .next: nextLayout
                }
                Spacer(minLength: 0)
                statusLabel
            }
        }
        .foregroundStyle(.black)
        .containerBackground(.white, for: .widget)
        .widgetURL(URL(string: "catchable://now"))
    }

    private var badgeLayout: some View {
        VStack(spacing: large ? 10 : 6) {
            ForEach(services) { service in
                VStack(alignment: .leading, spacing: small ? 5 : 4) {
                    stationHeader(service)
                    HStack(spacing: 7) {
                        Text(service.line)
                            .font(.system(size: small ? 12 : 11, weight: .bold))
                            .minimumScaleFactor(0.6).lineLimit(1)
                            .frame(width: small ? 30 : 26, height: small ? 30 : 26)
                            .foregroundStyle(.white)
                            .background(TransitTheme.routeColor(service.mode), in: Circle())
                        Text(service.destination)
                            .font(.system(size: small ? 12 : 11, weight: .semibold))
                            .lineLimit(small ? 2 : 1)
                    }
                    times(service, prominent: small)
                }
            }
        }
    }

    private var timetableLayout: some View {
        VStack(spacing: large ? 11 : 4) {
            ForEach(services) { service in
                VStack(alignment: .leading, spacing: 5) {
                    stationHeader(service)
                    if !small && !large {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(service.line).font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(TransitTheme.routeColor(service.mode))
                                Text(service.destination).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            times(service, prominent: false).frame(maxWidth: .infinity)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(service.line).font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(TransitTheme.routeColor(service.mode))
                            Text(service.destination).font(.system(size: 11, weight: .semibold)).lineLimit(small ? 2 : 1)
                        }
                        times(service, prominent: small)
                    }
                }
            }
        }
    }

    private var nextLayout: some View {
        Group {
            if small {
                nextPanel(services[0])
            } else {
                VStack(spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(services.prefix(2))) { nextPanel($0) }
                    }
                    if large && services.count > 2 {
                        Divider()
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(Array(services.dropFirst(2))) { nextPanel($0) }
                        }
                    }
                }
            }
        }
    }

    private func nextPanel(_ service: SavedService) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            stationHeader(service)
            Text("\(service.line) · \(service.destination)")
                .font(.system(size: 11, weight: .semibold)).lineLimit(2)
            if let departure = departures(service).first {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(minutes(departure))")
                        .font(.system(size: small ? 42 : 34, weight: .bold)).monospacedDigit()
                    Text("min").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                let following = departures(service).dropFirst().map { String(minutes($0)) }.joined(separator: " · ")
                if !following.isEmpty {
                    Text("Then \(following) min").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            } else {
                Text(walkingStatus(service) ?? "No departures").font(.system(size: 12, weight: .medium))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stationHeader(_ service: SavedService) -> some View {
        Text(service.station)
            .font(.system(size: small ? 11 : 10, weight: .bold))
            .lineLimit(1).truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 5).padding(.vertical, small || large ? 4 : 2)
            .foregroundStyle(.white).background(.black)
    }

    private func times(_ service: SavedService, prominent: Bool) -> some View {
        let values = Array(departures(service).prefix(small ? 1 : 3))
        return Group {
            if values.isEmpty {
                Text(walkingStatus(service) ?? "No catchable departures").font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(values.enumerated()), id: \.element.id) { index, departure in
                        if index > 0 { Rectangle().fill(.gray.opacity(0.25)).frame(width: 1, height: prominent ? 32 : 20) }
                        VStack(spacing: 0) {
                            Text("\(minutes(departure))")
                                .font(.system(size: prominent ? 32 : 20, weight: .bold)).monospacedDigit()
                            Text("min").font(.system(size: 9)).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var statusLabel: some View {
        Text(statusText).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
    }
    private var statusText: String {
        guard let snapshot = entry.snapshot else { return "Open Catchable to refresh" }
        if snapshot.isSample { return "Sample departures" }
        if entry.message != nil { return "Refresh unavailable · Saved departures" }
        if services.flatMap({ departures($0) }).contains(where: { !$0.isRealtime }) {
            return "Includes scheduled times"
        }
        let age = max(0, Int(entry.date.timeIntervalSince(snapshot.fetchedAt) / 60))
        return age == 0 ? "Updated just now" : "Updated \(age) min ago"
    }
    private func departures(_ service: SavedService) -> [Departure] {
        DepartureSelector().catchable(entry.snapshot?.departures ?? [], for: service,
                                     buffer: entry.place.bufferMinutes, now: entry.date)
    }
    private func walkingStatus(_ service: SavedService) -> String? {
        switch service.walkingState {
        case .pending: return "Set address or walking route in Catchable"
        case .unavailable: return "Walking route unavailable"
        default: return nil
        }
    }
    private func minutes(_ departure: Departure) -> Int {
        max(0, Int(ceil(departure.date.timeIntervalSince(entry.date) / 60)))
    }
    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: small ? 17 : 20, weight: .bold))
            Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(3)
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum WidgetPreviewData {
    static var entry: WidgetDepartureEntry {
        let now = Date()
        let place = PlaceStore.sample
        let departures = place.services.flatMap { service in
            [12, 22, 32].map { minute in
                Departure(id: "\(service.id)-\(minute)", serviceID: service.id,
                          date: now.addingTimeInterval(Double(service.walkingMinutes + place.bufferMinutes + minute) * 60))
            }
        }
        return WidgetDepartureEntry(date: now, place: place,
            snapshot: DepartureSnapshot(departures: departures, fetchedAt: now, isSample: true), message: nil)
    }
}

#Preview("Route badges", as: .systemSmall) {
    CatchableWidget(style: .badges, title: "Route badges", description: "Catchable departures")
} timeline: {
    WidgetPreviewData.entry
}

#Preview("Compact timetable", as: .systemMedium) {
    CatchableWidget(style: .timetable, title: "Compact timetable", description: "Catchable departures")
} timeline: {
    WidgetPreviewData.entry
}

#Preview("Next departure", as: .systemLarge) {
    CatchableWidget(style: .next, title: "Next departure", description: "Catchable departures")
} timeline: {
    WidgetPreviewData.entry
}
