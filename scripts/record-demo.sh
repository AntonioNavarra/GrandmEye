#!/bin/bash
# Records the README clip on a simulator, with a sample picture standing in for the camera.
#   scripts/record-demo.sh <simulator-udid> [out.gif]
# Needs a booted simulator. The app is the Debug build; the demo mode does not exist in Release.
set -euo pipefail
UDID="${1:?usage: record-demo.sh <simulator-udid> [out.gif]}"
OUT="${2:-docs/demo.gif}"
BUNDLE=com.ProjectsXcode.GrandmEye
WORK="$(mktemp -d)"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

xcodebuild -project "$ROOT/GrandmEye.xcodeproj" -scheme GrandmEye \
  -destination "id=$UDID" -derivedDataPath "$WORK/dd" CODE_SIGNING_ALLOWED=NO build >/dev/null
xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$WORK/dd/Build/Products/Debug-iphonesimulator/GrandmEye.app"

xcrun simctl io "$UDID" recordVideo --codec h264 --force "$WORK/clip.mp4" &
REC=$!
sleep 2
xcrun simctl launch "$UDID" "$BUNDLE" -AppleLanguages "(it)" -AppleLocale it_IT \
  -demoImagePath "$ROOT/docs/demo/leaflet.png" -demoClip YES >/dev/null
sleep 50
kill -INT "$REC"; wait "$REC" || true

# Seconds of the recording worth showing: simple screen, hold still, reading, advanced, contrast, still photo.
swift "$ROOT/scripts/clip-to-gif.swift" "$WORK/clip.mp4" "$ROOT/$OUT" 270 8 "3-4,5.5-8,14-20,26.2-27,29.5-36,40-43"
echo "wrote $OUT"
