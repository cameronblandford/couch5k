#!/bin/zsh
# Build the watch app and start it in a watch simulator. Arguments go to the app,
# for example: scripts/watch-sim.sh -autostart -warmup -fast 20
cd "$(dirname "$0")/.."
SIM=${WATCH_SIM:-"Apple Watch SE 3 (40mm)"}   # Apple Watch SE 3 (40mm), the smallest screen
DD=/tmp/couch5k-dd-watch
xcodegen generate >/dev/null || exit 1
xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1
xcodebuild -scheme Couch5kWatch -destination "platform=watchOS Simulator,name=$SIM" -derivedDataPath "$DD" build 2>&1 | grep -E "error:|BUILD" | tail -3
APP="$DD/Build/Products/Debug-watchsimulator/Couch5kWatch.app"
[ -d "$APP" ] || { echo "the build has no app"; exit 1; }
xcrun simctl terminate "$SIM" com.example.Couch5k.watchkitapp 2>/dev/null
xcrun simctl install "$SIM" "$APP" && xcrun simctl launch "$SIM" com.example.Couch5k.watchkitapp "$@"
