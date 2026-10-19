# Couch5k

A small iPhone and Apple Watch app for the standard nine-week Couch to 5K plan.
It has no account, no server, no ads, and no telemetry. It does not use the network.
Each run goes into Apple Health as a running workout with its route.

The NHS Couch to 5K app is only in the UK App Store. Couch5k follows the same plan, so people in other countries can use it in its place.
Couch5k is not from the NHS or the BBC, and it is not connected with them.

Site: https://couch5k.cam.fyi

## What it does

- **The plan.** 9 weeks, 3 runs each week, the same intervals as the NHS plan. Each run starts with a 5 minute walk and ends with a 5 minute walk.
  The next run is on the home screen. You can start any of the 27 runs from the plan grid.
  If you change from another app, mark the runs that you already did as done.
- **Voice cues over your music.** A chime and a spoken cue at each change ("Run for 3 minutes"). Your music becomes quieter for the cue and then comes back.
  "Halfway" in long runs, a minute count every 5 minutes in runs of 20 minutes or more, and a soft tick 10 seconds before each change.
- **Headphone buttons.** Pause and resume with the button on your headphones.
- **Lock screen.** A Live Activity shows the interval and the countdown.
- **Apple Health.** Each run is saved as a running workout with distance and the GPS route.
- **Crash safe.** If the app stops during a run, it asks to resume at the same second.
- **History and progress.** Each run has a map, the distance, the pace, the run pace and the walk pace, and the elevation gain. Charts show your pace from run to run.
- **Warmup drills.** An optional 3.5 minute warmup before the walk: A-skips, B-skips, high knees, jumps, butt kicks.
- **Apple Watch.** Do the full run from the watch without the phone. The watch taps your wrist at each cue, shows your heart rate, and sends the run to the phone later.
- **Units.** Kilometres or miles.

## Size

The release build is 5.7 MB on the phone, with the watch app and the widget. Compressed, it is about 1.5 MB.

## Privacy

- No network code. No analytics, crash reporting, or third-party libraries.
- Location is used only during a run, for the distance, the pace, and the route.
- Health: the phone app writes workouts and reads nothing. The watch app reads the heart rate only to show it during a run.
- Your runs stay on your phone, in Apple Health, and in the app's local store.

## Build it

You need a Mac with Xcode 26 and [xcodegen](https://github.com/yonaskolb/XcodeGen), and an iPhone with iOS 26 or later.

1. Set `DEVELOPMENT_TEAM` in `project.yml` to your Apple team id. Change the `com.example` bundle prefix to one that you own.
2. Run `xcodegen generate`.
3. Open `Couch5k.xcodeproj`, choose your iPhone, and press Run.

`scripts/install-device.sh <device id>` builds and installs from the command line. `xcrun devicectl list devices` shows the device id.

## Tests

- `scripts/test.sh` runs the unit tests in an iPhone simulator (`IOS_SIM`, iPhone 17 Pro by default).
- `scripts/watch-uitest.sh` taps through a full run in a watch simulator.

## Build your own

`docs/spec.md` is a full specification. Give it to a coding agent to make your own version.

## License

MIT
