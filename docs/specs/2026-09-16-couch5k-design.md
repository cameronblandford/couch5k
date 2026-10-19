# Couch5k Design

Date: 2026-09-16
Status: approved

## Goal

A personal, native iPhone Couch to 5K app that runs the standard 9-week plan with flawless audio coaching over other apps' audio, GPS distance and pace, HealthKit workout export, and a progress and history view that is pleasant to open. Single user, no accounts, no server, no Apple Watch.

## Non-goals

- Apple Watch app (added later, see the watch spec)
- Custom or adaptive plans
- Cloud sync, accounts, sharing
- App Store release polish (privacy manifest, marketing assets)
- Pre-recorded human voice (possible later upgrade)

## Platform

- Swift 6, SwiftUI, SwiftData, Swift Testing
- iOS 26 minimum
- Xcode project from `project.yml` (xcodegen), app target `Couch5k`, bundle ID `com.example.Couch5k`, widget extension target `Couch5kWidgets` for the Live Activity
- Background modes: audio, location

## Section 1: Plan and data model

### Plan

Static, code-defined. 9 weeks, 3 sessions each. Each session is an ordered list of intervals. An interval is a `kind` (warmup, run, walk, cooldown) and a `duration` in seconds. Not user-editable.

Reference schedule (Cool Running / NHS):

| Week | Session pattern |
|---|---|
| 1 | 5 min walk, 8 × (60 s run, 90 s walk), 5 min walk |
| 2 | 5 min walk, 6 × (90 s run, 2 min walk), 5 min walk |
| 3 | 5 min walk, 2 × (90 s run, 90 s walk, 3 min run, 3 min walk), 5 min walk |
| 4 | 5 min walk, 3 min run, 90 s walk, 5 min run, 2.5 min walk, 3 min run, 90 s walk, 5 min run, 5 min walk |
| 5 | d1: 5 min walk, 3 × (5 min run, 3 min walk), 5 min walk. d2: 5 min walk, 8 min run, 5 min walk, 8 min run, 5 min walk. d3: 5 min walk, 20 min run, 5 min walk |
| 6 | d1: 5 min walk, 5 min run, 3 min walk, 8 min run, 3 min walk, 5 min run, 5 min walk. d2: 5 min walk, 10 min run, 3 min walk, 10 min run, 5 min walk. d3: 5 min walk, 25 min run, 5 min walk |
| 7 | 5 min walk, 25 min run, 5 min walk |
| 8 | 5 min walk, 28 min run, 5 min walk |
| 9 | 5 min walk, 30 min run, 5 min walk |

Identity: `SessionID(week: Int, day: Int)`, 1-based.

### Persistence (SwiftData)

- **CompletedRun**: `id`, `week`, `day`, `startDate`, `endDate`, `distanceMeters`, `movingSeconds`, `averagePaceSecondsPerKm?`, `outcome` (completed | abandoned), `healthKitWorkoutID?`, relationship to `RoutePoint`s.
- **RoutePoint**: `latitude`, `longitude`, `timestamp`, `horizontalAccuracy`, parent `CompletedRun`.
- **UserProgress**: single record: `nextWeek`, `nextDay`, `totalRuns`. Advanced when a run completes with outcome completed. Any session can be started from the plan grid, which does not change `next` unless completed.

## Section 2: Workout engine

Plain Swift, no UI framework dependency. Inputs: a `Session` and a `Clock` protocol (`now() -> Date`). Output: `WorkoutState`.

Rules:

- **Wall-clock timing.** Store `startDate`. Elapsed = now − startDate − pausedOffset. A 1 Hz display timer only triggers recomputation.
- **Precomputed boundaries.** At start, build `[IntervalBoundary]` with absolute offsets from 0. Current interval = last boundary whose offset ≤ elapsed. Seconds remaining = next boundary offset − elapsed.
- **Pause as offset.** `pauseStartedAt: Date?`. On resume, `pausedOffset += now − pauseStartedAt`. While paused, elapsed is frozen.
- **Idempotent cues.** Each cue has a stable `CueID` (e.g. `.transition(index)`, `.tenSecondWarning(index)`, `.halfway(index)`, `.elapsed(minute)`, `.start`, `.complete`). `firedCues: Set<CueID>`. On each tick, collect due cues not yet fired. If more than one transition cue is due (long suspension), fire only the latest transition and mark earlier ones fired silently.
- **Recovery file.** On start and on every pause/resume, write `{sessionID, startDate, pausedOffset, pauseStartedAt, firedCues}` to `Application Support/active-run.json`. Delete on finish or abandon. On launch, if present, offer Resume or Discard.
- **Completion.** When elapsed ≥ total duration, state becomes `.finished`, `.complete` cue fires.

`WorkoutState`: `phase` (notStarted | running | paused | finished), `currentIntervalIndex`, `currentInterval`, `secondsRemainingInInterval`, `elapsedSeconds`, `totalSeconds`, `dueCues: [Cue]`.

## Section 3: Audio

- `AVAudioSession` category `.playback`, options `[.duckOthers, .mixWithOthers]`, mode `.spokenAudio`. Activate immediately before a cue; deactivate with `.notifyOthersOnDeactivation` when the cue finishes. Never hold the session active between cues.
- Speech via `AVSpeechSynthesizer`. Voice: user-selected from installed en voices, default to best quality (premium > enhanced > default) for the device locale.
- Chimes: two bundled short files (`run.caf`, `walk.caf`) via `AVAudioPlayer`, played before the spoken transition.
- Cue text:
  - start: "Week {w}, run {d}. Warm up with a 5 minute brisk walk."
  - transition: "{Run|Walk} for {duration in words}."
  - halfway (run intervals > 3 min): "Halfway."
  - 10 s warning: soft tick sound only.
  - cooldown: "Cool down. Walk for 5 minutes."
  - complete: "Great work. Week {w}, run {d} done."
  - elapsed every 5 min during run intervals ≥ 20 min: "{n} minutes."
  - pause: "Paused." resume: "Resuming."
- `MPRemoteCommandCenter` play/pause/toggle → engine pause/resume, so headphone buttons work.
- An `AudioCoach` type consumes `[Cue]` from the engine and serializes playback (chime, then speech) with a queue so overlapping cues never talk over each other.

## Section 4: Location and HealthKit

- `CLLocationManager`, when-in-use authorization, `allowsBackgroundLocationUpdates = true`, `activityType = .fitness`, `desiredAccuracy = kCLLocationAccuracyBest`, `distanceFilter = 5`, `pausesLocationUpdatesAutomatically = false`.
- Discard points with `horizontalAccuracy > 20` or `< 0`. Distance = sum of segment distances between consecutive accepted points, excluding segments that span a pause.
- Pace = rolling 30 s window: distance over time for accepted points within the last 30 s. Nil if under 20 m in window.
- HealthKit: on completion, save `HKWorkout` (activity `.running`, start/end, total distance) and an `HKWorkoutRoute` from accepted points via `HKWorkoutRouteBuilder`. Store the workout UUID on `CompletedRun`. Authorization requested once; if denied, save locally only and show state in Settings.
- Timer and audio never depend on location. Denied or no-fix location shows distance as "—".

## Section 5: Screens

Tab bar: Home, History. Workout is a full-screen cover.

- **Home**: hero card with next session (title, interval description, total time), Start button. Below: 9 × 3 plan grid, completed cells filled. Tapping a cell shows a session sheet with intervals and a Start button.
- **Workout**: `isIdleTimerDisabled = true`. Full-bleed background color by interval kind (run green, walk blue, warmup/cooldown neutral). Huge interval kind label, countdown in SF Rounded, segmented progress bar of all intervals at top, stats row (elapsed, distance, pace). Pause button; End requires confirmation dialog.
- **Live Activity**: `ActivityAttributes` with content state `{intervalKind, secondsRemaining, intervalIndex, intervalCount, elapsed}`. Compact, minimal, expanded and lock screen presentations. Updated once per second while running; on pause show "Paused".
- **Summary**: map with route polyline, time, distance, pace, interval bar. Save button writes to HealthKit (if authorized) and SwiftData, advances progress, dismisses. Discard is available with confirmation.
- **History**: list of `CompletedRun`s newest first: date, "Week w Run d", distance, small map snapshot. Tap → Summary in read-only mode.
- **Settings** (sheet from Home): voice picker with preview, chime toggle, units (km / mi), location and HealthKit status rows.

Visual direction: dark default, one accent, SF Rounded numerals, generous spacing, no nested cards.

## Section 6: Testing and layout

Folders in the app target:

```
Couch5k/
  Plan/         Interval, Session, SessionID, Plan (static table)
  Engine/       Clock, WorkoutEngine, Cue, CueScheduler, RunRecovery
  Audio/        AudioSessionController, SpeechCoach, ChimePlayer, RemoteCommands, AudioCoach
  Location/     RunTracker, DistanceCalculator, PaceCalculator
  Health/       HealthStore
  Persistence/  CompletedRun, RoutePoint, UserProgress, ModelContainer setup
  LiveActivity/ RunActivityAttributes (shared with widget target)
  UI/           Home/, Workout/, Summary/, History/, Settings/
Couch5kTests/
Couch5kWidgets/
```

Unit tests (Swift Testing):

- Plan: 27 sessions, each has warmup first and cooldown last, total durations match the reference table.
- Engine with fake clock: interval lookup at boundaries, pause freezes elapsed and resume offsets correctly, cues fire exactly once, catch-up after 5 min suspension fires only latest transition, completion state.
- Recovery: round-trip encode/decode restores identical state.
- Distance: rejects bad-accuracy points, sums segments, skips pause-spanning segments.
- Pace: rolling window, nil under threshold.

Manual checklist (real run):

1. Cue speaks over Spotify; Spotify volume restores immediately after.
2. AirPods tap pauses and resumes with spoken confirmation.
3. Screen off, phone in pocket for 20 minutes: every transition fires on time.
4. Force-quit mid-run, relaunch: Resume restores the correct interval and remaining time.
5. Workout appears in Apple Health with route.
6. Live Activity shows correct interval and countdown on lock screen.

Build order:

1. Plan + Engine + tests
2. Audio
3. Workout screen (enables real runs early)
4. Location + HealthKit + Summary
5. Live Activity
6. Home grid, History, Settings, visual polish
