#!/bin/zsh
# Run unit tests on an iPhone simulator (IOS_SIM, iPhone 17 Pro by default). Retries the transient simulator launch failure,
# and exits non-zero unless the tests actually succeeded, so `scripts/test.sh && git commit` is safe.
cd "$(dirname "$0")/.."
SIM=${IOS_SIM:-"iPhone 17 Pro"}
DEST="platform=iOS Simulator,name=$SIM"
xcrun simctl boot "$SIM" 2>/dev/null
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1
for attempt in 1 2 3; do
  out=$(xcodebuild -scheme Couch5k -destination "$DEST" test -only-testing:Couch5kTests 2>&1)
  if echo "$out" | grep -q "TEST SUCCEEDED"; then
    echo "$out" | grep -E "✔ Test run|TEST SUCCEEDED"
    exit 0
  fi
  # A named test failure or compile error is real: report it and stop. Anything else is a simulator hiccup: retry.
  if echo "$out" | grep -qE "✘|error:"; then
    echo "$out" | grep -E "error:|✘|Expectation failed|TEST FAILED"
    exit 1
  fi
  sleep 3
done
echo "$out" | grep -E "TEST FAILED|failed" | head -5
echo "tests did not run cleanly after 3 attempts"
exit 1
