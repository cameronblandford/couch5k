#!/bin/zsh
# Run the watch UI tests in a watch simulator. They tap through a full fast session.
# With a folder as the argument, the screenshots of the run go into it.
cd "$(dirname "$0")/.."
SIM=${WATCH_SIM:-"Apple Watch SE 3 (40mm)"}   # Apple Watch SE 3 (40mm), the smallest screen
RESULT=/tmp/couch5k-watch-uitest.xcresult
xcodegen generate >/dev/null || exit 1
xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1
command rm -rf "$RESULT"
out=$(xcodebuild -scheme Couch5kWatch -destination "platform=watchOS Simulator,name=$SIM" -derivedDataPath /tmp/couch5k-dd-watch -resultBundlePath "$RESULT" test 2>&1)
echo "$out" | grep -E "error:|Test Case .* (passed|failed)|TEST (SUCCEEDED|FAILED)"
if [ -n "$1" ]; then
  mkdir -p "$1" && xcrun xcresulttool export attachments --path "$RESULT" --output-path "$1" >/dev/null
fi
echo "$out" | grep -q "TEST SUCCEEDED"
