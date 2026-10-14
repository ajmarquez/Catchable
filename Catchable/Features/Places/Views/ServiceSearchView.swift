import SwiftUI

struct ServiceSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ServiceSearchViewModel()
    let onSelect: (SavedService) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Station or stop name", text: $viewModel.query)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                    if viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
                        Text("Type at least 3 characters to find a station.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if viewModel.isLoading { ProgressView("Loading…") }
                if let error = viewModel.errorMessage { Text(error).foregroundStyle(.red) }
                if let stop = viewModel.selectedStop {
                    Section("\(stop.name) — choose a direction") {
                        ForEach(viewModel.options) { option in
                            Button {
                                onSelect(SavedService(id: UUID().uuidString, station: stop.name,
                                    line: option.line, destination: option.destination, mode: option.mode,
                                    walkingMinutes: 0, stopID: stop.id, providerLineID: option.lineID,
                                    stationCoordinate: stop.coordinate, walkingState: .pending))
                                dismiss()
                            } label: {
                                VStack(alignment: .leading) {
                                    Text("\(option.line) → \(option.destination)")
                                    Text(option.mode.rawValue).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if !viewModel.isLoading && viewModel.options.isEmpty {
                            Text("No supported services in the next two hours. Try another stop or check again later.")
                        }
                    }
                } else {
                    Section("Stops") {
                        ForEach(viewModel.stops) { stop in
                            Button(stop.name) { Task { await viewModel.select(stop) } }
                                .disabled(viewModel.isLoading)
                        }
                    }
                }
            }
                .scrollContentBackground(.hidden)
                .background(Color.white)
                .navigationTitle("Add service")
                .task(id: viewModel.query) { await viewModel.search() }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
