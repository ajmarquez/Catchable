# Catchable

A native SwiftUI iPhone prototype: see three catchable departures per selected line and direction, grouped by station.

## Run
Open `Catchable.xcodeproj`, select the Catchable scheme and an iPhone simulator or device. Device installation requires choosing your signing team in Xcode. Deployment target: iOS 17+.

The committed project is generated from `project.yml` with XcodeGen (`xcodegen generate`). No third-party app dependencies.

## Architecture
- `Models`: domain types.
- `Networking`: injectable departure provider, sample implementation, HTTP boundary for future live integration.
- `Services`: pure catchability filtering and ordering.
- `Persistence`: Codable preferences in UserDefaults.
- `Features/Now` and `Features/Places`: SwiftUI views and observable MVVM view models.
- `Shared`: theme and reusable departure columns.

View models coordinate state; transport selection logic and persistence stay outside views. Dependencies are wired at the app entry point.

## First iteration scope
Now uses the selected Vignelli layout: black station headers, circular route badges, three numeric departure columns, digital clock, and “Departing from Home”. Places allows editing the label, optional address, buffer, stations, lines, directions, modes, and manual walking times. Settings persist across launches.

**All departures, routes and colors are illustrative. There is no live API connection, geocoding, calculated walking route, or home-exit monitoring yet.** The address is stored locally but does not drive routing. Samples refresh on opening Now, changing settings, or pulling to refresh. Countdown values update while visible.

## Validation
DepartureSelectorTests cover reachability boundaries, cancellation, service isolation, ordering, three-result limit, and persistence round-trip. Run with Xcode Product → Test after installing an iOS simulator runtime.

## Next
Validate VBB access and stop/direction identifiers; implement a live DepartureProvider; add stop discovery and MapKit walking estimates; then validate Core Location home-exit behavior on a physical device. No server or credentials configured yet.
