import SwiftUI
import MapKit

@MainActor struct LocationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    private let original: Place?
    private let onSave: (Place) -> Void
    private let searcher: any AddressSearching
    @State private var label: String
    @State private var query: String
    @State private var buffer: Int
    @State private var coordinate: GeoCoordinate?
    @State private var selectedAddress: String?
    @State private var results: [ResolvedAddress] = []
    @State private var isSearching = false
    @State private var error: String?
    @State private var selectionQuery: String?

    init(location: Place?, searcher: (any AddressSearching)? = nil, onSave: @escaping (Place) -> Void) {
        original = location
        self.searcher = searcher ?? MapKitAddressSearch()
        self.onSave = onSave
        _label = State(initialValue: location?.label ?? "")
        _query = State(initialValue: location?.address ?? "")
        _buffer = State(initialValue: location?.bufferMinutes ?? 1)
        _coordinate = State(initialValue: location?.coordinate)
        _selectedAddress = State(initialValue: location?.coordinate == nil ? nil : location?.address)
        _selectionQuery = State(initialValue: location?.coordinate == nil ? nil : location?.address)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Label, e.g. Home or Work", text: $label)
                    TextField("Search for an address", text: $query)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, value in
                            if value != selectionQuery {
                                coordinate = nil
                                selectedAddress = nil
                            }
                        }
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
                        Text("Type at least 3 characters and select an address below.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if isSearching { ProgressView("Finding addresses…") }
                    if let error { Text(error).font(.caption).foregroundStyle(.red) }
                    ForEach(results, id: \.id) { result in
                        Button {
                            selectionQuery = result.address
                            query = result.address
                            selectedAddress = result.address
                            coordinate = result.coordinate
                            results = []
                            error = nil
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.label).foregroundStyle(.primary)
                                Text(result.address).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if let coordinate {
                    Section("Selected address") {
                        Text(selectedAddress ?? "")
                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude),
                            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)))) {
                            Marker(label.isEmpty ? "Location" : label,
                                coordinate: CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude))
                        }.frame(height: 180).id("\(coordinate.latitude),\(coordinate.longitude)")
                            .accessibilityLabel("Map of selected address")
                    }
                }
                Section("Walking time") {
                    Stepper("Safety buffer: \(buffer) min", value: $buffer, in: 0...15)
                    Text("Walking times are calculated from this address to your selected stations.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle(original == nil ? "Add location" : "Edit location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
            .task(id: query) { await search() }
        }
    }

    private var canSave: Bool {
        LocationValidation.isValid(label: label, address: selectedAddress, coordinate: coordinate)
    }
    private func save() {
        guard canSave, let coordinate, let selectedAddress else { return }
        onSave(Place(label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                     address: selectedAddress, bufferMinutes: buffer, services: original?.services ?? [],
                     locationID: original?.locationID ?? UUID().uuidString, coordinate: coordinate))
        dismiss()
    }
    @MainActor private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []
        error = nil
        isSearching = false
        guard term.count >= 3, query != selectionQuery else { return }
        isSearching = true
        do {
            let found = try await searcher.search(term)
            guard !Task.isCancelled, query.trimmingCharacters(in: .whitespacesAndNewlines) == term else { return }
            results = found
            if found.isEmpty { error = "No matching addresses. Try a street and city." }
            isSearching = false
        } catch {
            guard !Task.isCancelled, query.trimmingCharacters(in: .whitespacesAndNewlines) == term else { return }
            self.error = "Could not search addresses. Please try again."
            isSearching = false
        }
    }
}
