import SwiftUI

struct WatchDeparturesView: View {
    @State private var model = WatchDeparturesViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Departing from \(model.place.label)")
                            .font(.caption).foregroundStyle(.secondary)
                        if model.place.services.filter(\.isSelected).isEmpty {
                            Text(model.message ?? "Choose stations on your iPhone.")
                                .font(.callout)
                        }
                        ForEach(model.place.services.filter(\.isSelected)) { service in
                            WatchServiceRow(service: service,
                                departures: model.departures(for: service, now: context.date), now: context.date)
                        }
                        if let message = model.message, !model.place.services.isEmpty {
                            Text(message).font(.caption2).foregroundStyle(.secondary)
                        }
                        Button { Task { await model.refresh() } } label: {
                            Label(model.isRefreshing ? "Refreshing" : "Refresh", systemImage: "arrow.clockwise")
                        }.disabled(model.isRefreshing)
                    }
                }.refreshable { await model.refresh() }
            }
            .navigationTitle("Catchable")
        }
        .tint(Color(red: 0.89, green: 0.04, blue: 0.08))
        .task { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name.catchableWatchStateDidChange)) { _ in
            Task { await model.refresh() }
        }
    }
}

private struct WatchServiceRow: View {
    let service: SavedService
    let departures: [Departure]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(service.station).font(.caption2.bold()).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(service.line).font(.caption.bold()).foregroundStyle(.red)
                Text(service.destination).font(.caption.bold()).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                if departures.isEmpty {
                    Text(service.walkingState == .pending ? "Set address on iPhone" : service.walkingState == .unavailable ? "Walking route unavailable" : "No catchable departures")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(departures) { departure in
                    Text("\(max(0, Int(ceil(departure.date.timeIntervalSince(now) / 60))))")
                        .font(.title2.bold()).monospacedDigit()
                }
                if !departures.isEmpty { Text("min").font(.caption2).foregroundStyle(.secondary) }
            }
            Text(service.walkingState == .pending ? "Walking time pending" : service.walkingState == .unavailable ? "Walking route unavailable" : "\(service.walkingMinutes) min walk")
                .font(.caption2).foregroundStyle(.secondary)
            if departures.contains(where: { !$0.isRealtime }) {
                Text("Includes scheduled times").font(.caption2).foregroundStyle(.secondary)
            }
            Divider()
        }
        .accessibilityElement(children: .combine)
    }
}
