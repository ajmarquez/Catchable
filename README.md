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
Now uses the selected Vignelli layout: black station headers, circular route badges, three numeric departure columns, digital clock, and “Departing from Home”. My Locations manages labelled, verified addresses and safety buffers. Stations manages stops and selected line/directions under each location. Now offers a departure-location switcher. Settings persist across launches.

## Live API integration
The default provider tries **VBB REST** (`https://v6.vbb.transport.rest`) first. A failed search or departure request falls back to **Transitous / MOTIS** (`https://api.transitous.org/api/v1/geocode` and `/api/v6/stoptimes`). A successful empty response stays empty, and cancelled requests never start fallback. VBB requests have an eight-second timeout; Transitous retains its existing timeout. API failures never silently enable sample mode.

New VBB search selections preserve the numeric stop ID and IFOPT identity, allowing each provider to receive its own ID. Existing Transitous selections work without reselecting. Legacy numeric-only selections resolve the fallback station by matching the exact VBB ID in station search results; unresolved identity fails rather than guessing another stop. Provider-specific route IDs differ, so matching across providers requires the same line name, transport mode and direction, normalizing cosmetic Berlin/transport-prefix/street-abbreviation differences.

In My Locations, add a label and select a real address from MapKit search results. In Stations, use Add station under that location, search a VBB stop and choose a line/direction. Walking time is calculated automatically. New installs start empty. Discovery lists supported services in the next 120 minutes, not a complete all-day catalogue. Search starts at three characters and updates with each further edit.

One departure-board request per selected stop fetches a 120-minute window. The selector removes cancellations and departures you cannot reach, returning the next three. Realtime flags come from provider data; scheduled fallback is labelled. Now displays the actual source, including mixed VBB/Transitous results. The same routing is used by iPhone, Home Screen widgets, Watch and complications. Home address is never sent to either transit API; stop searches and IDs are sent.

VBB REST is a third-party wrapper, not an official VBB API contract: https://v6.vbb.transport.rest/ . Transitous hosted use requires open-source, noncommercial access: https://transitous.org/api/ . Catchable is published under MIT; transit data retains its own source terms. Source/attribution links remain visible in Now, and clients include Catchable contact information.

Walking times use MapKit pedestrian routes, rounded up to whole minutes. No automatic home-exit monitoring yet.

## Validation
TransitousResponseTests cover response mapping, cancellation, scheduled fallback, realtime flags and legacy stop-ID rejection. LiveDepartureProviderTests exercise mocked HTTP response decoding, exact selected direction/line/product filtering, cancelled services, scheduled fallback, and legacy settings decoding. DepartureSelectorTests cover reachability boundaries, cancellation, service isolation, ordering, three-result limit, and persistence round-trip. Run with Xcode Product → Test after installing an iOS simulator runtime.

## Next
Validate the public provider on device and evaluate official VBB access before production; validate MapKit walking routes on device; then validate Core Location home-exit behavior on a physical device. No server or credentials configured yet.

## Navigation appearance
Use the system SwiftUI TabView with SF Symbols: `clock.fill` for Now, `tram.fill` for Stations, and `mappin.and.ellipse` for My Locations. On iOS 26 and later, the native tab bar adopts Liquid Glass; earlier supported versions use their native system appearance. Do not recreate the flat tab bar from the concept image or add custom tab-bar backgrounds.

### API verification status
On 2026-10-13, a live Swift check exercised VBB station search → M10 toward Warschauer Straße → three catchable departures. Forcing primary timeout exercised real Transitous fallback with the same saved station and direction, also returning three catchable departures. Both boards included realtime data. Deterministic tests cover routing, cancellation, empty results, ID translation, legacy identity resolution, and cross-provider direction filtering.

## Offline sample preview
In My Locations, enable **Use sample data**. Now displays three example stations without API access. Disable it to return to saved live services. Demo selection is explicit; API failures never silently enable it.

## Home Screen widgets
`CatchableWidgets` contains three native WidgetKit designs: Route badges, Compact timetable (no circular logos), and Next departure. Each supports small, medium, and large Home Screen sizes. There is no current-time clock. Add one from the Home Screen widget gallery after launching the app and saving services in Stations; widgets use that saved place, walking times, and buffer. Tap a widget to open Catchable.

`SharedWidget` stores the saved place and a matching departure cache in the App Group `group.com.ajmarquez.catchable`. Existing app-only preferences migrate when the app opens. Live widgets fetch through the same Transitous provider and apply the same departure selector as Now. Gallery previews use clearly labelled sample data. Widgets never silently substitute sample departures after a network error.

Minute timeline entries keep catchability filtering and countdown values moving between network refreshes. Refreshes request approximately 15-minute intervals; iOS controls actual scheduling. After 15 minutes, stale departures are hidden and the widget asks you to open Catchable. These widgets are glanceable departure boards, not guaranteed continuous realtime monitoring.

For physical devices, automatic signing must provision the App Group for both the app and `com.ajmarquez.catchable.widgets` extension. The extension is embedded through `project.yml`; regenerate with `xcodegen generate`. Version 0.1.0 (2), including widgets and the approved app icon, is available for internal TestFlight testing.

The original concept sheet remains in `Design/widget-concepts.png`; implemented widgets adapt the designs to native sizes and omit its clock.

## License
MIT for the code. Transit data, OpenStreetMap data, and design-reference assets retain their applicable source terms; the source-code license does not grant rights to third-party data or trademarks.


## Apple Watch
The `feature/watch-widgets` branch adds a watchOS 10+ companion app and WidgetKit extension. Rectangular accessories support the Smart Stack and compatible watch faces; circular and inline complications show the next departure. Widgets use the first selected service in the saved place, with the same walking time, buffer, cancellation and stale-data rules as iPhone. They omit the current-time clock and respect watch-face accent rendering.

Launch Catchable on both devices after installing. Save your live services on iPhone; WatchConnectivity transfers the latest place and optional live departure cache to the paired Watch. App Group containers are local to each device, so they do not provide cross-device sync. The Watch can fetch Transitous departures directly once it has received the configuration. Sample mode is intentionally local to iPhone; widget gallery examples are labelled samples. Widgets need refreshing after 15 minutes to keep displaying departure numbers.

`WatchConnectivityShared` owns the versioned sync envelope and session delegate; `CatchableWatch` owns Watch views and view model; `CatchableWatchWidgets` owns accessory rendering. `WidgetTimeline` is shared by both platforms. The iPhone app embeds the Watch app, which embeds its WidgetKit extension. Choose the CatchableWatch scheme to run on a Watch simulator. Actual background pairing and WatchConnectivity delivery must be verified with a physical paired iPhone/Watch before release. This branch has not been uploaded to TestFlight.


### Watch and failover validation
19 tests pass, including seven new failover cases. The signed iPhone archive embeds the signed Watch app and both widget extensions. Simulator visual checks verified the Watch companion app and a pinned rectangular Smart Stack widget using live M10 departures from a manually seeded saved-service configuration. This verifies rendering, the device-local App Group cache, and direct Watch networking; it does not verify cross-device WatchConnectivity delivery. Physical paired-device testing remains required. The Watch/failover branch is not merged or uploaded to TestFlight.


## Locations and walking routes
`feature/locations-walking-times` adds separate Now, Stations, and My Locations tabs. New locations require a label and a selected MapKit address, with a native SwiftUI map preview. Now manually selects one departure location; its stations, walking times and buffer also feed Home Screen widgets and Apple Watch. Automatic location switching is deferred.

`LocationsStore` persists the collection and active location in the App Group, retaining `PlaceStore` as a compatibility mirror of the active location. Existing single-place services migrate without being deleted; their prior manual walking estimates become pending until a real address is selected. Editing the origin invalidates walking results. Async route responses cannot restore deleted locations or overwrite a newer origin. Inactive location edits do not invalidate the active widget cache.

Station coordinates come from either transit API. Legacy station selections resolve coordinates by exact stop identity, never the first search result. MapKit calculates pedestrian routes once per station within a location, rounded up to minutes and cached with the service. Pending/failed routes are excluded from catchable departure selection across phone/widgets/Watch. Stations supports retrying walking calculations and swipe deletion of a station's selected services. Location deletion asks for confirmation.

Addresses and route endpoints are sent to Apple Maps for address search and walking directions. They are not sent to the transit APIs. No device-location permission is needed because the user selects a fixed address. The `Features/Locations/Services` boundary isolates MapKit from the shared domain models and widget targets. MapKit address search was verified with Frankfurter Allee 1, Berlin; its pedestrian route to Bersarinplatz returned 7 minutes during implementation. Physical route estimates may vary.


### Locations validation
30 tests pass, including location migration, per-location deletion, delayed route responses after origin edits/deletion, exact station-coordinate resolution, cross-provider station identity, and failed/pending walking routes. The signed archive (including Watch and widgets) builds without warnings. Live MapKit address search and pedestrian routing returned a 7-minute route from Frankfurter Allee 1 to Bersarinplatz. A simulator screenshot confirms the three native tabs; interactive location/station setup and swipe gestures still need checking because the Mac was locked during verification. This branch has not been merged or uploaded.


## Merged regression baseline
Watch support, VBB-first API fallback, and multiple locations with walking routes are merged into main. All 47 automated tests and the signed archive passed before merging. See [TESTING.md](TESTING.md) for coverage and remaining manual checks. These changes have not yet been uploaded to TestFlight.
