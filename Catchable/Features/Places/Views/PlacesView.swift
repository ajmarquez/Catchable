import SwiftUI

struct PlacesView: View {
    @Bindable var viewModel: PlacesViewModel
    @AppStorage("catchable.sampleMode") private var sampleMode = false
    @State private var isAddingService = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Preview") {
                    Toggle("Use sample data", isOn: $sampleMode)
                    Text("Shows three example stations in Now without an internet connection. Your saved live services are kept separately.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Main place") {
                    TextField("Place label", text: $viewModel.place.label)
                    TextField("Home address (optional)", text: $viewModel.place.address)
                    Stepper("Safety buffer: \(viewModel.place.bufferMinutes) min", value: $viewModel.place.bufferMinutes, in: 0...15)
                }
                Section {
                    Text("Search a stop and choose a line and direction. Set walking times manually for now.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Stations and selected directions") {
                    ForEach($viewModel.place.services) { $service in
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Include in Now", isOn: $service.isSelected)
                            Text(service.station).font(.headline)
                            if service.stopID == nil { Text("Sample service — remove and add a live service.").font(.caption).foregroundStyle(.orange) }
                            HStack {
                                Text(service.line)
                                Text(service.mode.rawValue).foregroundStyle(.secondary)
                            }
                            Text("→ " + service.destination)
                            Stepper("Walk: \(service.walkingMinutes) min", value: $service.walkingMinutes, in: 1...60)
                        }.padding(.vertical, 4)
                    }.onDelete { viewModel.place.services.remove(atOffsets: $0) }
                    Button("Add service", systemImage: "plus") { isAddingService = true }
                }
                if let error = viewModel.saveError { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Places")
                .sheet(isPresented: $isAddingService) {
                    ServiceSearchView { service in
                        let duplicate = viewModel.place.services.contains { $0.stopID == service.stopID && $0.providerLineID == service.providerLineID && $0.destination == service.destination }
                        if !duplicate { viewModel.place.services.append(service); viewModel.save() }
                    }
                }
                .onChange(of: viewModel.place) { _, _ in viewModel.save() }
        }
    }
}
