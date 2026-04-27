# Gradual Alarm

Gradual Alarm is an iOS alarm app for waking up gently. Instead of starting with
a loud alert, it plays a looping soundscape silently in the background, then
ramps volume up over a configurable window so full volume lands at the target
wake time.

The product strategy is reliability first: the gradual audio path is the
primary experience, while local notifications and AlarmKit system alarms provide
backup paths if iOS interrupts audio playback.

Built in Swift / SwiftUI.

## Strategy

Gradual Alarm should not compete as a broad alarm-clock replacement. Its wedge is
specific: people who want a calmer wake-up but still need the confidence of a
real alarm. The app should optimize for three things, in this order:

1. **Trust** — the alarm must be credible overnight. Every feature should
   preserve or improve backup behavior, diagnostics, and recovery.
2. **Calm wake quality** — sound choice, ramp shape, and peak volume should make
   waking feel intentional rather than abrupt.
3. **Low setup friction** — a user should be able to set tonight's alarm in a few
   seconds and understand what will happen.

This implies a conservative roadmap. Multi-alarm support, complex bedtime
automation, and heavy customization are lower priority than proving the core
overnight reliability loop on physical devices. The current architecture already
leans the right way: one alarm, explicit recovery diagnostics, audio route and
volume warnings, AlarmKit backup, snooze, nudge, and skip-next-occurrence.

## How it works

1. The user picks an **alarm time**, **repeat days**, **ramp duration**,
   **sound**, **ramp curve**, and **peak volume**.
2. The app computes the next matching alarm occurrence, respecting skipped
   occurrences.
3. The audio player arms immediately by starting the selected bundled `.wav`
   sound at volume `0` through `AVAudioSession` in `.playback` mode. This keeps
   the audio pipeline active while the app is backgrounded.
4. At `alarmTime - rampMinutes`, the app starts ramping volume according to the
   selected curve until it reaches the configured peak volume at the alarm time.
5. A local notification is scheduled at the alarm time as a fallback.
6. An AlarmKit system alarm is also scheduled for the target time. If enabled, a
   second nudge alarm is scheduled after the configured nudge delay.
7. When the gradual alarm reaches the alerting phase, the app presents a
   full-screen firing view with **Stop** and **Snooze** actions.
8. The app records diagnostics for arming, ramp start, stops, snoozes, backup
   scheduling, interruptions, route changes, media-service resets, and recovery
   outcomes.

## Current Features

- Single persisted alarm stored in `UserDefaults`.
- Repeat scheduling by weekday, with skip-next-occurrence support.
- Two bundled soundscapes: ocean waves and morning birds.
- Linear, ease-in, ease-out, and ease-in-out ramp curves.
- Configurable peak volume from 10% to 100%.
- Audio route warnings for headphones, Bluetooth, AirPlay, receiver output, and
  missing output.
- Low-volume warning using system output volume and configured peak volume.
- Full-screen firing view with stop and 10-minute snooze.
- Local notification fallback.
- AlarmKit system backup alarm with custom Stop and Snooze intents.
- Optional nudge system alarm if the first alarm is ignored.
- Persisted diagnostics surfaced in the app.

## Project Layout

```
Gradual-Alarm/
├── Gradual_AlarmApp.swift              # App entry point, injects AlarmStore
├── ContentView.swift                   # Empty legacy shell; MainView is used
├── Models/
│   ├── Alarm.swift                     # Alarm settings, scheduling helpers, persistence
│   └── AlarmDiagnostics.swift          # Lightweight persisted reliability diagnostics
├── ViewModels/
│   └── AlarmStore.swift                # MainActor ObservableObject; app orchestration
├── Services/
│   ├── AlarmOccurrenceScheduler.swift  # Coordinates each alarm occurrence
│   ├── AudioRampPlayer.swift           # AVAudioPlayer silent-arm and volume ramp
│   ├── BackupAlarmManager.swift        # AlarmKit backup and nudge alarms
│   └── NotificationManager.swift       # Local notification fallback
├── Views/
│   ├── MainView.swift                  # Main alarm settings and diagnostics UI
│   ├── TimePickerSheet.swift           # Alarm time picker
│   ├── RampPickerSheet.swift           # Ramp duration picker
│   ├── RepeatDaysPickerSheet.swift     # Weekday repeat picker
│   └── FiringView.swift                # Full-screen alarm controls
├── Resources/
│   ├── ocean-waves.wav
│   └── morning-birds.wav
└── Assets.xcassets
```

## Key Components

- **`Alarm`** — `Codable` value type for alarm time, ramp duration, repeat days,
  skipped occurrence, sound, peak volume, ramp curve, nudge settings, and
  `UserDefaults` persistence.
- **`AlarmStore`** — `@MainActor` `ObservableObject` used by the SwiftUI views.
  It owns the current alarm, firing state, environment warnings, diagnostics, and
  rescheduling calls.
- **`AlarmOccurrenceScheduler`** — Central scheduling coordinator for the active
  occurrence. It arms gradual audio, schedules local notification fallback,
  schedules AlarmKit backup, handles skip, stop, and snooze flows.
- **`AudioRampPlayer`** — Singleton around `AVAudioPlayer`. It silently arms the
  selected sound, drives the volume ramp, tracks playback phase, and attempts
  recovery after audio interruptions, route changes, and media-service resets.
- **`BackupAlarmManager`** — AlarmKit integration. It requests authorization when
  needed, schedules the system backup alarm and optional nudge alarm, persists
  backup state, and handles App Intent stop/snooze actions.
- **`NotificationManager`** — Local notification fallback and
  `UNUserNotificationCenterDelegate` implementation so alerts can present while
  the app is foregrounded.
- **`AlarmDiagnostics`** — Small persisted diagnostic record that makes overnight
  failures easier to reconstruct.

## Requirements

- Xcode 26.2 project settings are currently checked in.
- iOS 26.2 deployment target is currently configured.
- A physical device is recommended for testing. Simulator behavior for
  background audio, notification delivery, and AlarmKit does not fully match a
  real iPhone.

## Running

1. Open `Gradual-Alarm.xcodeproj` in Xcode.
2. Select a connected iPhone or compatible simulator.
3. Build and run.
4. Grant notification permission when prompted.
5. Grant AlarmKit permission when prompted so the system backup alarm can be
   scheduled.

## Reliability Notes

- The primary gradual wake path depends on a continuously running
  `AVAudioPlayer` in a playback audio session.
- The user should keep media volume high enough before sleep.
- Bluetooth, headphones, AirPlay, and receiver routing can make the alarm less
  audible; the app warns about these routes.
- A powered-off phone cannot run the app, play audio, or deliver backup alarms.
- AlarmKit backup is the credibility layer. Any future feature should be checked
  against whether it weakens backup scheduling, authorization, or stop/snooze
  recovery.

## Physical Device Reliability Checklist

Use a real iPhone for these checks. For each case, set the alarm a few minutes
ahead, lock the phone, wait for the ramp and target alarm time, then verify
gradual audio, local notification, AlarmKit backup, Stop, Snooze, and diagnostics.

- Baseline: app foregrounded, then locked with normal volume and speaker output.
- Background: arm the alarm, switch to another app, then lock the phone.
- Overnight-like: arm the alarm, lock the phone, leave it idle for at least one
  full ramp window before the alarm fires.
- Power: repeat while plugged in and unplugged.
- Low Power Mode: repeat with Low Power Mode enabled.
- Audio route: repeat with Bluetooth connected, then disconnect Bluetooth before
  the alarm fires.
- Headphones: verify the app warns when headphones are connected.
- Permissions: deny notification permission and confirm the app shows recovery
  guidance; repeat for AlarmKit permission.
- Recovery: start another audio app after arming and confirm diagnostics record
  interruption or route-change recovery.
- Nudge: enable nudge and ignore the first alarm until the nudge fires.

## Roadmap Priorities

1. Prove overnight reliability on physical devices and keep improving
   diagnostics around any failure.
2. Improve wake quality with longer-form ramp patterns, such as fade-in, hold,
   fade-out, then louder fade-in for longer wake windows.
3. Tighten the setup UX so the user can see at a glance: next alarm time, ramp
   start time, backup status, route status, and nudge status.
4. Consider additional soundscapes only after the reliability baseline is stable.
5. Defer multi-alarm support until the single-alarm model is boringly reliable.

## Caveats

- This is intentionally a single-alarm app for now.
- State persistence is lightweight and local only.
- Backup alarm behavior depends on AlarmKit authorization and OS support.
- Background audio reliability is improved with recovery logic and backup paths,
  but iOS can still interrupt or terminate app behavior under some conditions.
