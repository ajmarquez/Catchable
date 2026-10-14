import Foundation

struct ServiceNotice: Codable, Identifiable, Equatable {
    let id: String
    let serviceID: String
    let text: String
    let kind: String
}
