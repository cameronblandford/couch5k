#!/bin/zsh
# Build the app for your iPhone and install it. The phone must be unlocked, and on the same Wi-Fi or on the cable.
cd "$(dirname "$0")/.."
UDID=${1:?"usage: scripts/install-device.sh <device id from: xcrun devicectl list devices>"}
DD=/tmp/couch5k-dd-device
xcodegen generate >/dev/null || exit 1
xcodebuild -scheme Couch5k -destination "generic/platform=iOS" -derivedDataPath "$DD" -allowProvisioningUpdates build 2>&1 | grep -E "error:|BUILD" | tail -3
[ -d "$DD/Build/Products/Debug-iphoneos/Couch5k.app" ] || { echo "the build has no app"; exit 1; }
xcrun devicectl device install app --device "$UDID" "$DD/Build/Products/Debug-iphoneos/Couch5k.app" 2>&1 | grep -v "No provider" | tail -3
