import SwiftUI

struct PlacesView: View {
    @Bindable var viewModel: PlacesViewModel
    @State private var addingTo: Place?
    @State private var editingLocation: Place?

    var body: some View {
        NavigationStack {
            List {
                if viewModel.locations.isEmpty {
                    ContentUnavailableView("Add a location first", systemImage: "mappin.and.ellipse",
                        description: Text("Create Home in My Locations, then choose its stations here."))
                }
                ForEach(viewModel.locations, id: \.id) { location in
                    Section {
                        ForEach(stationGroups(location), id: \.key) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(group.services.first?.station ?? "Station").font(.headline)
                                ForEach(group.services) { service in
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack(alignment: .top, spacing: 8) {
                                            Text(service.line)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 7).padding(.vertical, 4)
                                                .background(TransitTheme.routeColor(service.mode))
                                            Text(service.destination).font(.subheadline.weight(.semibold))
                                        }
                                        Toggle("Include in Now", isOn: Binding(
                                            get: { currentSelection(serviceID: service.id, locationID: location.id) },
                                            set: { setSelection($0, serviceID: service.id, locationID: location.id) }))
                                            .font(.caption)
                                        Text(walkingLabel(service, location: location))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }.padding(.vertical, 5)
                            .swipeActions {
                                Button("Delete station", role: .destructive) {
                                    viewModel.deleteStation(stopID: group.key, from: location.id)
                                }
                            }
                        }
                        Button("Add station", systemImage: "plus") {
                            if location.coordinate == nil { editingLocation = location }
                            else { addingTo = location }
                        }
                        if location.coordinate == nil {
                            Text("Set this location’s address before adding stations.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Button("Update walking times", systemImage: "figure.walk") {
                                Task { await viewModel.recalculateWalkingTimes(locationID: location.id) }
                            }.disabled(viewModel.isCalculatingWalking)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(location.label).font(.headline)
                            if !location.address.isEmpty { Text(location.address).font(.caption) }
                        }
                        .textCase(nil).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12).background(.black)
                    }
                }
                if viewModel.isCalculatingWalking { ProgressView("Calculating walking times…") }
                if let error = viewModel.walkingError { Text(error).font(.caption).foregroundStyle(.red) }
                if let error = viewModel.saveError { Text(error).font(.caption).foregroundStyle(.red) }
            }
            .navigationTitle("Stations")
            .tint(TransitTheme.accent)
            .sheet(item: $addingTo) { location in
                ServiceSearchView { service in
                    Task { await viewModel.addService(service, to: location.id) }
                }
            }
            .sheet(item: $editingLocation) { location in
                LocationEditorView(location: location) { edited in
                    var updated = edited
                    updated.services = viewModel.locations.first { $0.id == edited.id }?.services ?? edited.services
                    viewModel.saveLocation(updated)
                }
            }
        }
    }

    private func walkingLabel(_ service: SavedService, location: Place) -> String {
        switch service.walkingState {
        case .calculated: return "\(service.walkingMinutes) min walk · \(location.bufferMinutes) min buffer"
        case .pending: return "Walking time pending"
        case .unavailable: return "Walking route unavailable · Try updating walking times"
        case nil: return "Walking time needs calculation"
        }
    }
    private struct StationGroup {
        let key: String
        var services: [SavedService]
    }
    private func stationGroups(_ location: Place) -> [StationGroup] {
        var groups: [StationGroup] = []
        for service in location.services {
            let key = service.stopID.flatMap { StopReference($0)?.vbbID } ?? service.stopID ?? service.station
            if let index = groups.firstIndex(where: { $0.key == key }) { groups[index].services.append(service) }
            else { groups.append(StationGroup(key: key, services: [service])) }
        }
        return groups
    }
    private func currentSelection(serviceID: String, locationID: String) -> Bool {
        viewModel.locations.first(where: { $0.id == locationID })?.services.first(where: { $0.id == serviceID })?.isSelected ?? false
    }
    private func setSelection(_ selected: Bool, serviceID: String, locationID: String) {
        guard var location = viewModel.locations.first(where: { $0.id == locationID }),
              let index = location.services.firstIndex(where: { $0.id == serviceID }) else { return }
        location.services[index].isSelected = selected
        viewModel.saveLocation(location)
    }
}
