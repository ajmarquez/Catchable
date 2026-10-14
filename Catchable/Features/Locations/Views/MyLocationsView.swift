import SwiftUI

struct MyLocationsView: View {
    @Bindable var viewModel: PlacesViewModel
    @AppStorage("catchable.sampleMode") private var sampleMode = false
    @State private var editingLocation: Place?
    @State private var isAdding = false
    @State private var deletingLocation: Place?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose where you depart from. Catchable uses its address to calculate your walk to each station.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Your locations") {
                    ForEach(viewModel.locations, id: \.id) { location in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(location.label).font(.headline)
                                Spacer()
                                if viewModel.activeLocationID == location.id {
                                    Label("Active", systemImage: "checkmark.circle.fill")
                                        .font(.caption).foregroundStyle(TransitTheme.accent)
                                }
                            }
                            Text(location.address.isEmpty ? "Address required" : location.address)
                                .font(.subheadline).foregroundStyle(.secondary)
                            HStack {
                                if viewModel.activeLocationID != location.id {
                                    Button("Depart from here") { viewModel.selectLocation(id: location.id) }
                                }
                                Spacer()
                                Button("Edit", systemImage: "pencil") { editingLocation = location }
                            }.buttonStyle(.borderless)
                        }.padding(.vertical, 5)
                        .listRowBackground(Color(white: 0.97))
                        .swipeActions {
                            Button("Delete", role: .destructive) { deletingLocation = location }
                        }
                    }
                    Button("Add location", systemImage: "plus") { isAdding = true }
                }
                if let error = viewModel.saveError { Section { Text(error).foregroundStyle(.red) } }
                Section("Preview") {
                    Toggle("Use sample data", isOn: $sampleMode)
                    Text("Shows example departures. Your saved locations and stations are kept separately.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle("My Locations")
            .confirmationDialog("Delete \(deletingLocation?.label ?? "location") and its saved stations?", isPresented: Binding(
                get: { deletingLocation != nil }, set: { if !$0 { deletingLocation = nil } }), titleVisibility: .visible) {
                    Button("Delete location", role: .destructive) {
                        if let deletingLocation { viewModel.deleteLocation(id: deletingLocation.id) }
                        deletingLocation = nil
                    }
                }
            .sheet(item: $editingLocation) { location in
                LocationEditorView(location: location) { edited in
                    var updated = edited
                    updated.services = viewModel.locations.first { $0.id == edited.id }?.services ?? edited.services
                    viewModel.saveLocation(updated)
                }
            }
            .sheet(isPresented: $isAdding) {
                LocationEditorView(location: nil) { viewModel.saveLocation($0) }
            }
        }
    }
}
