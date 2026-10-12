import SwiftUI

@main struct CatchableApp: App {
    @State private var places = PlacesViewModel(store: PlaceStore())
    @State private var now = NowViewModel(provider: SampleDepartureProvider())
    var body: some Scene {
        WindowGroup {
            TabView {
                NowView(places: places, viewModel: now).tabItem { Label("Now", systemImage: "clock.fill") }
                PlacesView(viewModel: places).tabItem { Label("Places", systemImage: "mappin.circle.fill") }
            }.tint(TransitTheme.accent).preferredColorScheme(.light)
        }
    }
}
