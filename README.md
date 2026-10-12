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

## Live API integration
The default provider is now **Transitous / MOTIS**, using `https://api.transitous.org/api/v1/geocode` and `/api/v6/stoptimes`. The previous transport.rest adapter remains available in code but is not used as a silent fallback.

In Places, disable Use sample data, tap Add service, search a VBB stop, select a line/direction, and set your walking time. Saved transport.rest/sample services need to be reselected because Transitous uses different IDs. New installs start empty. Discovery lists supported services in the next 120 minutes, not a complete all-day catalogue.

One request per selected stop fetches a 120-minute departure window. The adapter maps Transitous responses into shared transport types. Filtering retains the selected route, transport mode and headsign, removes cancellations and unreachable departures, and returns three times. Realtime flags come from the provider; scheduled fallback is labeled. Home address is never sent; stop searches and saved stop IDs are sent.

Transitous prototype testing is permitted before source publication. Continued hosted use requires an open-source, noncommercial project: https://transitous.org/api/ . The source is published under the MIT license. Transitous hosted access is limited to noncommercial use, independently of the code license. Requests include `Catchable/0.1` with the owner's website as contact. Visible Transitous data-source and OpenStreetMap attribution links are included in Now. Before public distribution, review individual data-source attribution terms and confirm the contact URL.

Walking times remain manual. No automatic home-exit monitoring yet.

## Validation
TransitousResponseTests cover response mapping, cancellation, scheduled fallback, realtime flags and legacy stop-ID rejection. LiveDepartureProviderTests exercise mocked HTTP response decoding, exact selected direction/line/product filtering, cancelled services, scheduled fallback, and legacy settings decoding. DepartureSelectorTests cover reachability boundaries, cancellation, service isolation, ordering, three-result limit, and persistence round-trip. Run with Xcode Product → Test after installing an iOS simulator runtime.

## Next
Validate the public provider on device and evaluate official VBB access before production; add MapKit walking estimates; then validate Core Location home-exit behavior on a physical device. No server or credentials configured yet.

## Navigation appearance
Use the system SwiftUI TabView with SF Symbols: `clock.fill` for Now and `mappin.circle.fill` for Places. On iOS 26 and later, the native tab bar adopts Liquid Glass; earlier supported versions use their native system appearance. Do not recreate the flat tab bar from the concept image or add custom tab-bar backgrounds.

### API verification status
Transitous successfully returned stop search and M10 departures for Bersarinplatz during implementation. A live Swift check exercised stop search → selected route/direction → provider mapping → three catchable departures, with realtime flags present in the final response. Earlier responses had scheduled-only data, confirming availability can vary. Simulator/device UI verification remains outstanding. The previous transport.rest host timed out; its related BVG host returned HTTP 503.

## Offline sample preview
In Places, enable **Use sample data**. Now displays three example stations without API access. Disable it to return to saved live services. Demo selection is explicit; API failures never silently enable it.

## Widget concepts
Three Vignelli-inspired medium widget directions are in `Design/widget-concepts.png`: route badges, a compact timetable without circular logos, and next-departure panels. These are concept graphics with sample times, not an implemented WidgetKit extension.

## License
MIT for the code. Transit data, OpenStreetMap data, and design-reference assets retain their applicable source terms; the source-code license does not grant rights to third-party data or trademarks.
