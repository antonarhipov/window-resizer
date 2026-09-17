#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$PROJECT_ROOT/build/WindowResizer.app"
TEMP_BUILD="$(mktemp -d)"
trap 'rm -rf "$TEMP_BUILD"' EXIT

APP_VERSION="${WINDOW_RESIZER_VERSION:-$(<"$PROJECT_ROOT/VERSION")}"
BUILD_NUMBER="${WINDOW_RESIZER_BUILD_NUMBER:-1}"
BUILD_CONFIGURATION="${WINDOW_RESIZER_BUILD_CONFIGURATION:-Release}"
SIGNING_IDENTITY="${WINDOW_RESIZER_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
    SIGNING_IDENTITY="-"
fi

if [[ "$BUILD_CONFIGURATION" == "Release" ]]; then
    SWIFT_OPTIMIZATION_FLAGS=(-O -whole-module-optimization)
else
    SWIFT_OPTIMIZATION_FLAGS=(-Onone)
fi

SOURCES=(
    "$PROJECT_ROOT/WindowResizer/App/WindowResizerApp.swift"
    "$PROJECT_ROOT/WindowResizer/Models/TargetWindow.swift"
    "$PROJECT_ROOT/WindowResizer/Services/AccessibilityWindowService.swift"
    "$PROJECT_ROOT/WindowResizer/Services/DimensionOverlayController.swift"
    "$PROJECT_ROOT/WindowResizer/ViewModels/WindowResizerViewModel.swift"
    "$PROJECT_ROOT/WindowResizer/Views/ContentView.swift"
    "$PROJECT_ROOT/WindowResizer/Views/WindowRow.swift"
)

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"

xcrun swiftc \
    -emit-executable \
    -parse-as-library \
    "${SWIFT_OPTIMIZATION_FLAGS[@]}" \
    -target arm64-apple-macosx14.0 \
    -module-cache-path "$TEMP_BUILD/module-cache-arm64" \
    -o "$TEMP_BUILD/WindowResizer-arm64" \
    "${SOURCES[@]}"

xcrun swiftc \
    -emit-executable \
    -parse-as-library \
    "${SWIFT_OPTIMIZATION_FLAGS[@]}" \
    -target x86_64-apple-macosx14.0 \
    -module-cache-path "$TEMP_BUILD/module-cache-x86_64" \
    -o "$TEMP_BUILD/WindowResizer-x86_64" \
    "${SOURCES[@]}"

lipo -create \
    "$TEMP_BUILD/WindowResizer-arm64" \
    "$TEMP_BUILD/WindowResizer-x86_64" \
    -output "$APP_BUNDLE/Contents/MacOS/WindowResizer"

cp "$PROJECT_ROOT/WindowResizer/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleExecutable -string WindowResizer "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string com.anton.WindowResizer "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleName -string "Window Resizer" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$APP_VERSION" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace LSMinimumSystemVersion -string 14.0 "$APP_BUNDLE/Contents/Info.plist"

if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP_BUNDLE"
else
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
fi
codesign --verify --deep --strict "$APP_BUNDLE"

echo "Built Window Resizer $APP_VERSION ($BUILD_CONFIGURATION) at $APP_BUNDLE"
