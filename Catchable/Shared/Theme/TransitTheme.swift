import SwiftUI

enum TransitTheme {
    static let accent = Color(red: 0.89, green: 0.04, blue: 0.08)
    static func routeColor(_ mode: TransportMode) -> Color {
        switch mode {
        case .tram: return accent
        case .subway: return Color(red: 0.48, green: 0.27, blue: 0.16)
        case .bus: return .blue
        case .suburban: return .green
        case .regional: return .purple
        }
    }
}
