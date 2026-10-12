import SwiftUI

struct PlacesView: View {
    @Bindable var viewModel: PlacesViewModel
    var body: some View {
        NavigationStack {
            Form {
                Section("Main place") {
                    TextField("Place label", text: $viewModel.place.label)
                    TextField("Home address (optional)", text: $viewModel.place.address)
                    Stepper("Safety buffer: \(viewModel.place.bufferMinutes) min", value: $viewModel.place.bufferMinutes, in: 0...15)
                }
                Section {
                    Text("Prototype: services and walking times are entered manually. Nearby-stop search and calculated routes come after provider validation.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Stations and selected directions") {
                    ForEach($viewModel.place.services) { $service in
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Include in Now", isOn: $service.isSelected)
                            TextField("Station", text: $service.station)
                            HStack {
                                TextField("Line", text: $service.line)
                                Picker("Mode", selection: $service.mode) {
                                    ForEach(TransportMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                                }.labelsHidden()
                            }
                            TextField("Selected direction", text: $service.destination)
                            Stepper("Walk: \(service.walkingMinutes) min", value: $service.walkingMinutes, in: 1...60)
                        }.padding(.vertical, 4)
                    }.onDelete { viewModel.place.services.remove(atOffsets: $0) }
                    Button("Add service", systemImage: "plus") { viewModel.addService() }
                }
                if let error = viewModel.saveError { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Places")
                .onChange(of: viewModel.place) { _, _ in viewModel.save() }
        }
    }
}
