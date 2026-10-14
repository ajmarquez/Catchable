import SwiftUI

struct StationCard: View {
    let services: [SavedService]
    let place: Place
    let now: Date
    let viewModel: NowViewModel
    @State private var showingNotices = false
    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(services.first?.station ?? "").font(.system(size: 16, weight: .bold))
                    noticeButton
                    Spacer(minLength: 8)
                    walkingLabel
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(services.first?.station ?? "").font(.headline)
                        Spacer()
                        noticeButton
                    }
                    walkingLabel
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(12).foregroundStyle(.white).background(.black)
            ForEach(services) { service in
                let departures = viewModel.departures(for: service, place: place, now: now)
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            routeBadge(service)
                            Text(service.destination)
                                .font(.headline)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        DepartureColumns(departures: departures, now: now)
                            .frame(maxWidth: .infinity)
                    }
                    if !departures.isEmpty && departures.contains(where: { !$0.isRealtime }) {
                        Text("Includes scheduled times").font(.caption2).foregroundStyle(.secondary)
                    }
                    if departures.isEmpty {
                        Text(service.walkingState == .pending ? "Walking time needs calculating. Check Stations." :
                            service.walkingState == .unavailable ? "Walking route unavailable. Retry in Stations." :
                            "No catchable departures in the next 2 hours").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(12)
                if service.id != services.last?.id { Divider().padding(.horizontal, 12) }
            }
        }.background(.white).clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.2), lineWidth: 1))
            .sheet(isPresented: $showingNotices) {
                StationNoticesView(station: services.first?.station ?? "Station", notices: viewModel.notices(for: services))
            }
    }
    @ViewBuilder private var noticeButton: some View {
        if !viewModel.notices(for: services).isEmpty {
            Button { showingNotices = true } label: {
                Image(systemName: "info.circle").font(.body).frame(minWidth: 44, minHeight: 44)
            }.buttonStyle(.plain)
                .accessibilityLabel("Announcements for \(services.first?.station ?? "station")")
        }
    }
    private var walkingLabel: some View {
        Text(services.first?.walkingState == .pending ? "Walking time pending" :
            services.first?.walkingState == .unavailable ? "Walking route unavailable" :
            "\(services.first?.walkingMinutes ?? 0) min walk · \(place.bufferMinutes) min buffer")
            .font(.caption)
    }
    private func routeBadge(_ service: SavedService) -> some View {
        Text(service.line).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            .minimumScaleFactor(0.6).lineLimit(1).padding(4)
            .frame(width: 38, height: 38).background(TransitTheme.routeColor(service.mode), in: Circle())
            .accessibilityLabel("\(service.mode.rawValue) \(service.line)")
    }
}
