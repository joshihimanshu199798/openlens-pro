# OpenLens Pro

OpenLens Pro is an offline-first Android camera prototype built with Flutter.

## Current features
- Live camera preview with front/back camera switching
- Flash mode controls where supported
- Zoom and exposure compensation controls
- Tap-to-focus/exposure where supported by the device
- Selectable rule-of-thirds, center, portrait-frame, and golden-ratio composition guides
- Live aesthetic color grading with curated film, cinematic, portrait, and monochrome presets
- Filtered-copy photo export
- Video filter export using FFmpeg while retaining the original recording if grading fails
- Dark camera-focused interface

## Current limitations
- ISO and shutter-speed manual controls require a native Android Camera2 implementation and are not included yet.
- Camera and encoder capabilities vary by device; test video filter exports on the target phone.
- Actual support for zoom, focus, flash and exposure depends on the device camera.

## Build an Android APK
The GitHub Actions workflow runs Flutter analysis and tests, then builds a release APK. Open the repository's **Actions** tab and download the `openlens-pro-v0.3.0-verified-release-apk` artifact from a successful run. The workflow generates the Android platform scaffold when needed, sets the minimum Android SDK required by the video-processing dependency, and uploads the APK only after analysis, tests, and the release build succeed.

For local builds, install Flutter and Android SDK. If the repository has no `android/` folder yet, first generate it with:
```sh
flutter create --platforms=android --org com.openlenspro --project-name openlens_pro .
```
Then run:
```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

This is a prototype, not a verified production camera app. Test on your device before relying on it.


## Build status
The automated Android build runs on pushes to `main` and can also be started manually from the repository's Actions tab.
