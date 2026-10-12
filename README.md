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
The app now uses `https://v6.vbb.transport.rest`, a third-party open-source wrapper around VBB/HAFAS, not direct official VBB credentials. No API key or server is configured. Provider docs: https://v6.vbb.transport.rest/api.html

In Places, tap Add service, search a stop, select a line and direction, then adjust walking time. Discovery lists supported services observed in the next 120 minutes; it is not a complete all-day line catalogue. New installations start empty. Previously saved sample entries remain visible in Places but must be replaced with API-backed selections.

Departures are fetched on opening Now, changing settings, or pulling to refresh, once per unique selected stop. They are filtered by saved provider line ID, transport product and exact destination, then by cancellation, walking time and safety buffer. Results are limited to three per service within a 120-minute window. Scheduled times are used when realtime information is unavailable and labeled accordingly. Failures are shown, with no silent sample-data fallback.

Walking times remain manual. Address is stored locally but does not drive routing. No automatic home-exit monitoring yet. Stop IDs are sent to the provider; home address is not.

## Validation
LiveDepartureProviderTests exercise mocked HTTP response decoding, exact selected direction/line/product filtering, cancelled services, scheduled fallback, and legacy settings decoding. DepartureSelectorTests cover reachability boundaries, cancellation, service isolation, ordering, three-result limit, and persistence round-trip. Run with Xcode Product → Test after installing an iOS simulator runtime.

## Next
Validate the public provider on device and evaluate official VBB access before production; add MapKit walking estimates; then validate Core Location home-exit behavior on a physical device. No server or credentials configured yet.

## Navigation appearance
Use the system SwiftUI TabView with SF Symbols: `clock.fill` for Now and `mappin.circle.fill` for Places. On iOS 26 and later, the native tab bar adopts Liquid Glass; earlier supported versions use their native system appearance. Do not recreate the flat tab bar from the concept image or add custom tab-bar backgrounds.

### API verification status
The integration compiles and mocked HTTP checks pass. During implementation, v6.vbb.transport.rest requests timed out and the related v6.bvg.transport.rest endpoint returned HTTP 503. A successful live end-to-end response and on-device UI verification remain outstanding. No fallback host is silently used.

## Offline sample preview
In Places, enable **Use sample data**. Now displays three example stations without API access. Disable it to return to saved live services. Demo selection is explicit; API failures never silently enable it.
