# TestFlight release

Catchable is configured as `com.ajmarquez.catchable`, version `0.1.0`, build `2`, with automatic signing for the personal Apple Developer team. The app icon uses the approved white geometric C on transit red. The archive embeds the Home Screen widget extension, signed with the shared App Group.

## Archive

```sh
xcodebuild -project Catchable.xcodeproj -scheme Catchable -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Catchable-0.1.0-build2.xcarchive \
  -allowProvisioningUpdates archive
```

## First upload

Open the archive in Xcode Organizer and select **Distribute App → TestFlight Internal Only**. Xcode can create the App Store Connect app record with name Catchable Berlin, English (United States), and SKU `com.ajmarquez.catchable`.

After the app record exists, command-line upload is available:

```sh
xcodebuild -exportArchive -archivePath build/Catchable-0.1.0-build2.xcarchive \
  -exportOptionsPlist Release/ExportOptions.plist -exportPath build/TestFlight \
  -allowProvisioningUpdates
```

## Current status

Version `0.1.0 (2)` uploaded successfully on 2026-10-12 at 22:57 Europe/Berlin. Xcode confirmed **Upload succeeded**, **EXPORT SUCCEEDED**, and **Uploaded package is processing**.

The App Store Connect record is **Catchable Berlin** (app ID `6822076442`), because the name Catchable was already in use. The installed app name remains Catchable. [TestFlight](https://appstoreconnect.apple.com/apps/6822076442/testflight/ios)

Apple processing completed. Build 2 is assigned to Internal Testing and Personal, with the account owner configured as a tester. Internal TestFlight distribution is enabled. No App Store release was submitted.

The encryption declaration is false because the app uses system HTTPS and does not implement non-exempt encryption.

External testing requires separate beta review and tester setup.


## Build 3 uploaded
Version **0.1.0 (3)** uploaded successfully on 2026-10-14 at 07:43 Europe/Berlin. Xcode confirmed **Upload succeeded**, **EXPORT SUCCEEDED**, and **Uploaded package is processing**.

This build includes Watch support, VBB-first API fallback, multiple locations and MapKit walking times. All 47 regression tests passed before release preparation. The signed archive is `build/Catchable-0.1.0-build3.xcarchive`; all embedded components use build 3.

App Store Connect browser sign-in is required to independently confirm processing completion and group availability. No App Store release was submitted.
