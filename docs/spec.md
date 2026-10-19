# Couch5k specification

Give this file to a coding agent to build your own Couch to 5K app for iPhone and Apple Watch.
It describes the app at https://couch5k.cam.fyi. The source is at https://github.com/cameronblandford/couch5k.

## Goals

- Run the standard nine-week Couch to 5K plan with clear audio coaching over other apps' audio.
- Record GPS distance, pace, and the route. Save each run to Apple Health as a running workout with its route.
- Keep the app small. Use only Apple frameworks. No network access, no account, no server, no analytics.
- Survive a crash or a force-quit during a run.

## Non-goals

- Custom or adaptive plans.
- Cloud sync, accounts, sharing, social features.
- Recorded human voices. Use the system speech voices.

## Platform

- Swift 6 with strict concurrency, SwiftUI, SwiftData, Swift Testing.
- iOS 26 and watchOS 26 minimum. iPhone only (no iPad layout).
- Frameworks: AVFoundation, ActivityKit, WidgetKit, CoreLocation, HealthKit, MapKit, Charts, MediaPlayer, WatchConnectivity.
- Targets: the iPhone app, a widget extension for the Live Activity, and a watch app that the iPhone app embeds.
- Background modes: `audio` and `location` on the phone; `workout-processing` and `location` on the watch.
- Generate the Xcode project from `project.yml` with xcodegen.

## 1. The plan

Static and defined in code. 9 weeks, 3 sessions each, 27 sessions. A session is an ordered list of intervals.
An interval has a kind (warmup, run, walk, cooldown) and a duration in seconds.
Each session starts with a 5 minute warmup walk and ends with a 5 minute cooldown walk.

| Week | Work between the warmup and the cooldown |
|---|---|
| 1 | 8 × (60 s run, 90 s walk) |
| 2 | 6 × (90 s run, 2 min walk) |
| 3 | 2 × (90 s run, 90 s walk, 3 min run, 3 min walk) |
| 4 | 3 min run, 90 s walk, 5 min run, 2.5 min walk, 3 min run, 90 s walk, 5 min run |
| 5 | Run 1: 3 × (5 min run, 3 min walk). Run 2: 8 min run, 5 min walk, 8 min run. Run 3: 20 min run |
| 6 | Run 1: 5 min run, 3 min walk, 8 min run, 3 min walk, 5 min run. Run 2: 10 min run, 3 min walk, 10 min run. Run 3: 25 min run |
| 7 | 25 min run |
| 8 | 28 min run |
| 9 | 30 min run |

When the work ends with a walk, join that walk to the cooldown: one longer cooldown, one cue, the same total time.
A session's identity is `(week, day)`, 1-based. The next session is the one after the furthest session that is complete.

## 2. Workout engine

Plain Swift with no UI dependency. Inputs: a session and a clock protocol (`now() -> Date`). Output: a state value.

- **Wall-clock time.** Store the start date. Elapsed = now − start − paused offset. A 1 Hz timer only causes a new calculation.
- **Boundaries.** At the start, calculate the start offset of each interval. The current interval is the last one whose offset is not more than the elapsed time.
- **Pause.** Store the pause start. On resume, add the paused time to the paused offset. Elapsed time does not change while paused.
- **Cues fire once.** Each cue has a stable id: start, transition(i), ten-second warning(i), halfway(i), elapsed minute(n), complete. Keep a set of fired ids.
  If more than one transition is due at the same time (for example after the app was suspended), speak only the latest and mark the others as fired.
- **Recovery file.** At the start and at each pause and resume, write the session id, start date, paused offset, pause start, fired cues, and recorded segments to `Application Support/active-run.json`.
  Delete it when the run ends. At launch, if it exists, offer Resume or Discard.
- **Segments.** Record each interval as a segment with its distance and time, so that the summary can show the run pace and the walk pace.

## 3. Audio

- `AVAudioSession`: category `.playback`, options `.duckOthers` and `.mixWithOthers`, mode `.spokenAudio`.
  Activate the session just before a cue. Deactivate it with `.notifyOthersOnDeactivation` when the cue ends, so that the user's music becomes loud again at once.
- Speech: `AVSpeechSynthesizer`. The user picks a voice from the installed English voices. The default is the best quality voice.
- Chimes: two short bundled sounds, one for run and one for walk, played before the spoken cue. A soft tick for the 10 second warning. Chimes can be turned off.
- Cue text:
  - start: "Week 3, run 2. Warm up with a 5 minute brisk walk."
  - transition: "Run for 3 minutes." or "Walk for 90 seconds."
  - halfway, in run intervals longer than 3 minutes: "Halfway."
  - every 5 minutes, in run intervals of 20 minutes or more: "10 minutes."
  - cooldown: "Cool down. Walk for 5 minutes."
  - complete: "Great work. Week 3, run 2 done."
  - pause and resume: "Paused." "Resuming."
- A queue plays the cues in sequence (chime, then speech), so two cues never play at the same time.
- `MPRemoteCommandCenter`: play, pause, and toggle go to the engine, so the headphone buttons pause and resume the run.

## 4. Location and Health

- `CLLocationManager`: when-in-use permission, background updates on, activity type fitness, best accuracy, distance filter 5 m, no automatic pause.
- Ignore points with a horizontal accuracy of more than 20 m or less than 0.
  Distance is the sum of the segments between accepted points. Do not count a segment that spans a pause.
- Pace: distance over time for the accepted points in the last 30 seconds. No value when the window has less than 20 m.
- Elevation gain from the altitude of the accepted points, with a small threshold to ignore noise.
- The timer and the audio never wait for location. With no location, show the distance as "—".
- During the run, use an `HKWorkoutSession` with an `HKLiveWorkoutBuilder` so that the run shows as a live workout.
  At the end, save a running workout with the start, the end, and the distance, plus an `HKWorkoutRoute` from the accepted points.
  Store the workout UUID with the run. If the user refuses Health access, save the run in the app only.

## 5. Data (SwiftData)

- **CompletedRun:** id, week, day, start date, end date, distance, moving seconds, average pace, outcome (completed or ended early), Health workout id, route points, segments.
- **RoutePoint:** latitude, longitude, altitude, timestamp, horizontal and vertical accuracy.
- **RunSegment:** interval kind, start, end, distance.
- **UserProgress:** derived from the completed runs.

## 6. Screens (iPhone)

Tabs: Home, Progress, History. The run is a full-screen cover.

- **Home:** a card with the next session (title, intervals, total time) and a Start button. Under it, a 9 × 3 grid of the plan. Completed cells are filled.
  Tap a cell to see that session's intervals, to start it, or to mark it as done (only this run, or this run and all earlier runs, for people who change from another app). A Settings button opens Settings.
- **Warmup (optional):** five drills on the spot, about 3.5 minutes, each with a one-line instruction that is shown and spoken.
  A-skips 45 s, B-skips 45 s, high knees 30 s, jump in place 60 s, butt kicks 30 s. Not saved to Health.
- **Run:** keep the screen on. The background color shows the interval kind (run, walk, warmup or cooldown).
  A large interval name and countdown, a progress bar of all intervals with a halfway mark, and a row with elapsed time, remaining time, distance, and pace.
  Show the current pace against recent runs (faster or slower). Pause button. End needs a confirmation.
- **Live Activity:** interval kind, seconds left, interval number and count, elapsed time. Compact, minimal, expanded, and lock screen forms. Update once a second. Show "Paused" when paused and a finished state at the end.
- **Summary:** route map, time, distance, average pace, run pace and walk pace, elevation gain, and the interval bar. Save writes to Health and to SwiftData. Discard needs a confirmation.
- **History:** runs, newest first: date, "Week 3 Run 2", distance, and a small drawing of the route. Tap a run to see its summary.
- **Progress:** charts of the longest run, the pace (all, run, and walk), the distance, and the elevation gain for each run, and a table of all runs.
- **Settings:** voice with a preview, chimes on or off, warmup drills on or off, kilometres or miles, and the state of the location and Health permissions.

Visual direction: dark, one accent color, SF Rounded numbers, generous spacing.

## 7. Apple Watch

- The watch runs a full session with no phone in reach: the plan, the warmup drills, the run with its cues, the summary, and the save to Health.
- The watch compiles the same plan, engine, audio, location, and Health files as the phone, so a watch run and a phone run use the same figures.
- The phone owns the history. It sends a short list of all runs to the watch (WatchConnectivity application context). The watch finds the next session from that list.
- A watch run goes to the phone with `transferUserInfo`, which the system delivers later if the phone is not in reach.
  The phone stores it with the same id, so a run that arrives twice is stored once. The watch keeps its copy until the phone confirms it.
- Cues on the watch: a tap on the wrist for each cue (run and walk feel different), plus the chimes and the voice, which have switches.
- The live Health workout keeps the watch app active with the wrist down and gives the heart rate.
- Watch screens: Home, the plan, warmup, run (controls, interval, figures), summary, history (read only), settings.

## 8. Privacy

- No network code. No third-party libraries.
- Health usage strings: the phone writes workouts and reads nothing. The watch reads the heart rate only to show it.
- Location only while a run is in progress.

## 9. Tests

- Plan: 27 sessions; a warmup first and a cooldown last; the totals agree with the table.
- Engine with a fake clock: the interval at each boundary; pause and resume; each cue fires once; after a 5 minute suspension only the latest transition fires; completion.
- Recovery: encode and decode give the same state.
- Distance: bad points are ignored; segments over a pause are not counted.
- Pace: the rolling window; no value under the threshold.
- Watch sync: the payload round trip; a run that arrives twice is stored once.

Manual checks on a real run:

1. A cue plays over music, and the music becomes loud again at once.
2. A headphone tap pauses and resumes the run, with a spoken confirmation.
3. With the screen off and the phone in a pocket for 20 minutes, each change plays on time.
4. After a force-quit during a run, Resume goes back to the correct interval and time.
5. The workout is in Apple Health with its route.
6. The Live Activity shows the correct interval and countdown.
