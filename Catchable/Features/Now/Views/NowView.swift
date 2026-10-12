import SwiftUI

struct NowView: View {
    let places: PlacesViewModel
    let viewModel: NowViewModel
    private var selected: [SavedService] { places.place.services.filter(\.isSelected) }
    private var stations: [String] {
        selected.reduce(into: []) { if !$0.contains($1.station) { $0.append($1.station) } }
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("CATCHABLE").font(.system(size: 13, weight: .bold)).tracking(3)
                    HStack {
                        Text("Now").font(.system(size: 40, weight: .bold))
                        Spacer()
                        Text(context.date, format: .dateTime.hour().minute()).font(.system(size: 23, weight: .semibold)).monospacedDigit()
                    }
                    Text("Departing from \(places.place.label)").font(.title3).foregroundStyle(.secondary).padding(.bottom, 4)
                    if viewModel.isLoading { ProgressView("Loading departures…").frame(maxWidth: .infinity) }
                    if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
                    if selected.isEmpty {
                        ContentUnavailableView("Choose your services", systemImage: "tram", description: Text("Add or enable a service in Places."))
                    }
                    ForEach(stations, id: \.self) { station in
                        StationCard(services: selected.filter { $0.station == station }, place: places.place, now: context.date, viewModel: viewModel)
                    }
                    if let snapshot = viewModel.snapshot {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.isSample ? "Sample departures · Not live transport data" : "Live departures")
                            Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(16)
            }.refreshable { await viewModel.refresh(place: places.place) }
        }.task(id: places.place) { await viewModel.refresh(place: places.place) }
    }
}
