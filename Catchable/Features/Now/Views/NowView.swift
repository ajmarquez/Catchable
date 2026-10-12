import SwiftUI

struct NowView: View {
    let places: PlacesViewModel
    let viewModel: NowViewModel
    @AppStorage("catchable.sampleMode") private var sampleMode = false
    private var activePlace: Place { sampleMode ? PlaceStore.sample : places.place }
    private var selected: [SavedService] { activePlace.services.filter { $0.isSelected && (sampleMode || $0.stopID != nil) } }
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
                    Text("Departing from \(activePlace.label)").font(.title3).foregroundStyle(.secondary).padding(.bottom, 4)
                    if viewModel.isLoading { ProgressView("Loading departures…").frame(maxWidth: .infinity) }
                    if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
                    if !sampleMode && places.place.services.contains(where: { $0.isSelected && $0.stopID == nil }) {
                        Text("Old sample services are not connected. Replace them using Add service in Places.").font(.caption).foregroundStyle(.secondary)
                    }
                    if selected.isEmpty {
                        ContentUnavailableView("Choose your services", systemImage: "tram", description: Text("Add a live service or enable Use sample data in Places."))
                    }
                    ForEach(stations, id: \.self) { station in
                        StationCard(services: selected.filter { $0.station == station }, place: activePlace, now: context.date, viewModel: viewModel)
                    }
                    if let snapshot = viewModel.snapshot {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.isSample ? "Sample departures · Not live transport data" : "VBB via transport.rest · Live where available")
                            Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(16)
            }.refreshable { await viewModel.refresh(place: activePlace, sampleMode: sampleMode) }
        }.task(id: RefreshKey(place: activePlace, sampleMode: sampleMode)) { await viewModel.refresh(place: activePlace, sampleMode: sampleMode) }
    }
}

private struct RefreshKey: Equatable {
    let place: Place
    let sampleMode: Bool
}
