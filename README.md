# Window Resizer

A small native macOS utility for resizing an individual application window to an exact width and height.

Current version: **0.1.0**

## Run it

The ready-to-run local build is `build/WindowResizer.app`. Double-click it in Finder, or build it again with:

```sh
./Scripts/build-app.sh
```

You can also open `WindowResizer.xcodeproj` in Xcode, select the **WindowResizer** scheme, and run it.

Then:

1. Choose **Open Accessibility Settings** when prompted, enable Window Resizer in **System Settings > Privacy & Security > Accessibility**, then return to the app.
2. Enter a width and height, select a window, and choose **Resize Window**.

Selecting a window row restores that specific window if needed and brings it to the front. When you resize it manually from an edge or corner, a floating hint shows its live dimensions and the configured target size.

Dimensions are expressed in macOS points. Target applications can enforce minimum sizes or other constraints; when that happens, Window Resizer reports the size the application actually used.

## Build and test from Terminal

```sh
xcodebuild -project WindowResizer.xcodeproj -scheme WindowResizer build
xcodebuild -project WindowResizer.xcodeproj -scheme WindowResizer test
```

`Scripts/build-app.sh` creates an optimized universal release by default. Set `WINDOW_RESIZER_BUILD_CONFIGURATION=Debug` for an unoptimized local build.

Window Resizer is intentionally not sandboxed because macOS Accessibility APIs must communicate with other applications' windows. It does not use the network or persist a history of window titles.

### If access is enabled but not detected

Accessibility access is tied to the exact signed application build. Remove the existing **WindowResizer** row from System Settings, use the **+** button to add the `build/WindowResizer.app` copy, enable it, then quit and reopen that same copy. Rebuilding the app locally changes its ad-hoc signature, so access must be granted again after a rebuild.

## Releases

CI builds and tests the app on pushes and pull requests. Pushing a version tag such as `v0.1.0` creates a GitHub release containing a universal macOS ZIP and SHA-256 checksum.

Release builds are ad-hoc signed unless these GitHub repository secrets are configured:

- `MACOS_CERTIFICATE_BASE64`: Developer ID Application certificate exported as a base64-encoded `.p12`
- `MACOS_CERTIFICATE_PASSWORD`: password for that `.p12`
- `APPLE_ID`: Apple account used for notarization
- `APPLE_TEAM_ID`: Apple Developer team identifier
- `APPLE_APP_PASSWORD`: app-specific Apple account password

When all signing and Apple secrets are present, the release job uses hardened-runtime Developer ID signing, submits the app to Apple for notarization, and staples the ticket before packaging it.
