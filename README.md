# OpenLens Pro

OpenLens Pro is an offline-first Android camera prototype built with Flutter.

## Current features
- Live camera preview with front/back camera switching
- Flash mode controls where supported
- Zoom and exposure compensation controls
- Tap-to-focus/exposure where supported by the device
- Composition grid overlay
- Dark camera-focused interface

## Current limitations
- ISO and shutter-speed manual controls require a native Android Camera2 implementation and are not included yet.
- Video mode is a placeholder.
- Captured images currently use the camera plugin's temporary/cache path and are not yet saved to the system gallery.
- Actual support for zoom, focus, flash and exposure depends on the device camera.

## Build an Android APK
The GitHub Actions workflow runs Flutter analysis and tests, then builds a release APK. Open the repository's **Actions** tab and download the `openlens-pro-release-apk` artifact from a successful run.

For local builds, install Flutter and Android SDK, then run:
```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

This is a prototype, not a verified production camera app. Test on your device before relying on it.


## Build status
The automated Android build runs on pushes to `main` and can also be started manually from the repository's Actions tab.
