import SwiftUI

struct StationCard: View {
    let services: [SavedService]
    let place: Place
    let now: Date
    let viewModel: NowViewModel
    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(services.first?.station ?? "").font(.system(size: 16, weight: .bold))
                    Spacer(minLength: 8)
                    walkingLabel
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(services.first?.station ?? "").font(.headline)
                    walkingLabel
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(12).foregroundStyle(.white).background(.black)
            ForEach(services) { service in
                let departures = viewModel.departures(for: service, place: place, now: now)
                VStack(alignment: .leading, spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            routeBadge(service)
                            Text(service.destination).font(.system(size: 14, weight: .semibold))
                            Spacer(minLength: 4)
                            DepartureColumns(departures: departures, now: now).frame(width: 135)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { routeBadge(service); Text(service.destination).font(.headline) }
                            DepartureColumns(departures: departures, now: now)
                        }
                    }
                    if departures.isEmpty { Text("No catchable departures").font(.caption).foregroundStyle(.secondary) }
                }.padding(12)
                if service.id != services.last?.id { Divider().padding(.horizontal, 12) }
            }
        }.background(.white).clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    private var walkingLabel: some View {
        Text("\(services.first?.walkingMinutes ?? 0) min walk · \(place.bufferMinutes) min buffer")
            .font(.caption)
    }
    private func routeBadge(_ service: SavedService) -> some View {
        Text(service.line).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
            .minimumScaleFactor(0.6).lineLimit(1).padding(4)
            .frame(width: 38, height: 38).background(TransitTheme.routeColor(service.mode), in: Circle())
            .accessibilityLabel("\(service.mode.rawValue) \(service.line)")
    }
}
