import SwiftUI

struct NowView: View {
    let places: PlacesViewModel
    let viewModel: NowViewModel
    @AppStorage("catchable.sampleMode") private var sampleMode = false
    private var activePlace: Place { sampleMode ? PlaceStore.sample : places.place }
    private var selected: [SavedService] { activePlace.services.filter { $0.isSelected && (sampleMode || $0.stopID.map { FailoverTransitAPI().supportsStopID($0) } == true) } }
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
                    if !sampleMode && places.place.services.contains(where: { $0.isSelected && $0.stopID.map { FailoverTransitAPI().supportsStopID($0) } != true }) {
                        Text("Some services have unsupported stop IDs. Reselect them in Places.").font(.caption).foregroundStyle(.secondary)
                    }
                    if selected.isEmpty {
                        ContentUnavailableView("Choose your services", systemImage: "tram", description: Text("Add a live service or enable Use sample data in Places."))
                    }
                    ForEach(stations, id: \.self) { station in
                        StationCard(services: selected.filter { $0.station == station }, place: activePlace, now: context.date, viewModel: viewModel)
                    }
                    if let snapshot = viewModel.snapshot {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.isSample ? "Sample departures · Not live transport data" : "\(snapshot.source ?? "VBB REST · Transitous fallback") · Realtime where available")
                            Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                            if !snapshot.isSample {
                                Link("VBB REST", destination: URL(string: "https://v6.vbb.transport.rest/")!)
                                Link("Transitous data sources", destination: URL(string: "https://transitous.org/sources/")!)
                                Link("© OpenStreetMap contributors", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                            }
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
