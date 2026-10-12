import SwiftUI

@main struct CatchableApp: App {
    @State private var places = PlacesViewModel(store: PlaceStore())
    @State private var now = NowViewModel(provider: LiveDepartureProvider())
    var body: some Scene {
        WindowGroup {
            // System TabView owns the tab bar and adopts native Liquid Glass on iOS 26+.
            // Keep SF Symbols and avoid custom backgrounds or replacement tab bars.
            TabView {
                NowView(places: places, viewModel: now)
                    .tabItem { Label("Now", systemImage: "clock.fill") }
                PlacesView(viewModel: places)
                    .tabItem { Label("Places", systemImage: "mappin.circle.fill") }
            }.tint(TransitTheme.accent).preferredColorScheme(.light)
        }
    }
}
