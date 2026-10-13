import Foundation

enum LocationValidation {
    static func isValid(label: String, address: String?, coordinate: GeoCoordinate?) -> Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        address?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
        coordinate?.isValid == true
    }
}
