import Foundation
import MapKit

struct ResolvedAddress: Identifiable {
    let id: String
    let label: String
    let address: String
    let coordinate: GeoCoordinate
}

@MainActor protocol AddressSearching {
    func search(_ query: String) async throws -> [ResolvedAddress]
}

@MainActor struct MapKitAddressSearch: AddressSearching {
    func search(_ query: String) async throws -> [ResolvedAddress] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        request.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 52.52, longitude: 13.405),
            latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        let search = MKLocalSearch(request: request)
        let response = try await withTaskCancellationHandler {
            try await search.start()
        } onCancel: { search.cancel() }
        try Task.checkCancellation()
        return response.mapItems.compactMap { item in
            let mark = item.placemark
            guard mark.thoroughfare != nil else { return nil }
            let coordinate = GeoCoordinate(latitude: mark.coordinate.latitude, longitude: mark.coordinate.longitude)
            guard coordinate.isValid else { return nil }
            let street = [mark.thoroughfare, mark.subThoroughfare].compactMap { $0 }.joined(separator: " ")
            let city = [mark.postalCode, mark.locality].compactMap { $0 }.joined(separator: " ")
            let address = [street, city, mark.country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
            return ResolvedAddress(id: "\(coordinate.latitude),\(coordinate.longitude):\(address)",
                label: item.name ?? street, address: address, coordinate: coordinate)
        }
    }
}

@MainActor protocol WalkingTimeProviding {
    func walkingMinutes(from: GeoCoordinate, to: GeoCoordinate) async throws -> Int
}

@MainActor struct MapKitWalkingTimeProvider: WalkingTimeProviding {
    func walkingMinutes(from: GeoCoordinate, to: GeoCoordinate) async throws -> Int {
        guard from.isValid, to.isValid else { throw WalkingError.invalidCoordinate }
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: from.latitude, longitude: from.longitude)))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: to.latitude, longitude: to.longitude)))
        request.transportType = .walking
        let directions = MKDirections(request: request)
        let response = try await withTaskCancellationHandler {
            try await directions.calculate()
        } onCancel: { directions.cancel() }
        try Task.checkCancellation()
        guard let route = response.routes.first, route.expectedTravelTime.isFinite, route.expectedTravelTime >= 0 else {
            throw WalkingError.noRoute
        }
        return max(1, Int(ceil(route.expectedTravelTime / 60)))
    }

    enum WalkingError: Error { case invalidCoordinate, noRoute }
}
