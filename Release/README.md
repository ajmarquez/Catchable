# TestFlight release

Catchable is configured as `com.ajmarquez.catchable`, version `0.1.0`, build `1`, with automatic signing for the personal Apple Developer team. The initial app icon is a red transit-style C.

## Archive

```sh
xcodebuild -project Catchable.xcodeproj -scheme Catchable -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Catchable-0.1.0.xcarchive \
  -allowProvisioningUpdates archive
```

## First upload

Open the archive in Xcode Organizer and select **Distribute App → TestFlight Internal Only**. Xcode can create the App Store Connect app record with name Catchable, English (United States), and SKU `com.ajmarquez.catchable`.

After the app record exists, command-line upload is available:

```sh
xcodebuild -exportArchive -archivePath build/Catchable-0.1.0.xcarchive \
  -exportOptionsPlist Release/ExportOptions.plist -exportPath build/TestFlight \
  -allowProvisioningUpdates
```

## Current status

A signed release archive succeeded on 2026-10-12. App Store Connect registration/upload was blocked by Apple's **PLA Update available** response: the account holder must accept the latest Apple Developer Program License Agreement in their developer account before retrying. No build has been uploaded yet.

The encryption declaration is false because the app uses system HTTPS and does not implement non-exempt encryption.

Internal TestFlight availability still requires Apple processing and adding the build to an internal testing group. External testing requires separate beta review and tester setup.
