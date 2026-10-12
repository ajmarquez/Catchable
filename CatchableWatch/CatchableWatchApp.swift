import SwiftUI

@main
struct CatchableWatchApp: App {
    init() { WatchSyncCoordinator.shared.start() }

    var body: some Scene {
        WindowGroup { WatchDeparturesView() }
            .backgroundTask(.watchConnectivity) {
                // Finish only after pending WCSession content has been persisted.
                await WatchSyncCoordinator.shared.handleBackgroundDelivery()
            }
    }
}
