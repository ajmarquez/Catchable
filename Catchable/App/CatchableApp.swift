import SwiftUI

@main struct CatchableApp: App {
    @State private var places = PlacesViewModel(store: PlaceStore())
    @State private var now = NowViewModel(provider: LiveDepartureProvider())
    @State private var selectedTab = 0
    var body: some Scene {
        WindowGroup {
            // System TabView owns the tab bar and adopts native Liquid Glass on iOS 26+.
            // Keep SF Symbols and avoid custom backgrounds or replacement tab bars.
            TabView(selection: $selectedTab) {
                NowView(places: places, viewModel: now)
                    .tabItem { Label("Now", systemImage: "clock.fill") }
                    .tag(0)
                PlacesView(viewModel: places)
                    .tabItem { Label("Stations", systemImage: "tram.fill") }
                    .tag(1)
                MyLocationsView(viewModel: places)
                    .tabItem { Label("My Locations", systemImage: "mappin.and.ellipse") }
                    .tag(2)
            }.tint(TransitTheme.accent).preferredColorScheme(.light)
                .task {
                    WatchSyncCoordinator.shared.start()
                    await places.resumeWalkingCalculations()
                }
                .onOpenURL { url in
                    if url.scheme == "catchable", url.host == "now" { selectedTab = 0 }
                }
        }
    }
}
