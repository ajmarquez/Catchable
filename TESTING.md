# Regression verification

Before merging the Watch/API and locations branches on 2026-10-13, all 47 automated tests passed and the signed Release archive succeeded without warnings. The archive includes the iPhone app, Home Screen widgets, Watch app and Watch widget extension.

## Covered behavior

- Catchability: walking time plus buffer, cancellation, service isolation, sorting and three-result limit.
- API routing: VBB first, Transitous after failure, provider-specific IDs, direction matching, cancellation and successful empty responses.
- Search/feed concurrency: three-character threshold, each subsequent edit, stale search responses, and all overlapping refresh success/error combinations.
- Locations: migration, required address/label/coordinates, deletion isolation, selection persistence, active-place mirroring and cache invalidation.
- Walking: exact station coordinates, per-station route reuse, failure/pending exclusions and rejecting delayed responses after origin edits or deletion.
- Widgets: sample rejection, matching-place cache, expiry, future-dated boards, minute-by-minute reachability and preserved refresh-error messages.
- Watch: payload compatibility, sample rejection, ordered incoming state, retaining fresher Watch boards and clearing the old location's departures.

Tests use injected providers and isolated preferences; live service availability is checked separately. Live VBB/Transitous failover and MapKit address/routing checks previously succeeded. Full interactive location setup/swipe gestures and physical paired-device WatchConnectivity delivery remain manual checks. Automated tests cannot guarantee every possible regression.

## Run

Open Catchable.xcodeproj and use Product > Test with an installed iPhone simulator. Regenerate the project with xcodegen generate after adding source files. Archive the Catchable scheme for a generic iOS device with automatic provisioning to verify all embedded targets.


## Announcement update
51 tests pass after adding four notice tests: German remarks parsing and metadata filtering; malformed optional remark tolerance; deduplication and saved-direction isolation including cancelled departures; station-card notice isolation and cache Codable round-trip. Native Translation language downloads and translated output require an iPhone check.
