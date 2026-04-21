# Gradual Alarm

An iOS alarm app that wakes you up gently by ramping the volume of a looped soundscape from silent up to full over a configurable window, instead of jolting you awake with an instant blast of sound.

Built in Swift / SwiftUI.

## How it works

1. You pick an **alarm time** and a **ramp duration** (1–30 minutes).
2. When the app is active, it *arms* itself by starting the bundled audio file (`ocean-waves.wav`) at volume `0` through `AVAudioSession` in `.playback` mode. This keeps the audio pipeline alive in the background so iOS doesn't suspend playback before the ramp starts.
3. At `alarmTime - rampMinutes`, the app begins ramping the player's volume linearly from `0` → `1` over the chosen window, reaching full volume exactly at the alarm time.
4. A local notification is also scheduled at the alarm time as a fallback in case the audio pipeline gets killed by the OS.
5. When the alarm fires, a full-screen `FiringView` is presented over the app so you can stop the current occurrence with a single tap.
6. The app records lightweight diagnostics for armed state, ramp start, interruptions, route changes, media-service resets, and recovery attempts so overnight failures are easier to debug.

## Project layout

```
Gradual-Alarm/
├── Gradual_AlarmApp.swift        # App entry point, injects AlarmStore
├── ContentView.swift
├── Models/
│   ├── Alarm.swift               # Alarm settings + persistence to UserDefaults
│   └── AlarmDiagnostics.swift    # Lightweight persisted reliability diagnostics
├── ViewModels/
│   └── AlarmStore.swift          # @MainActor ObservableObject; orchestrates scheduling
├── Services/
│   ├── AudioRampPlayer.swift     # AVAudioPlayer-based silent-arm + recovery-aware volume ramp
│   └── NotificationManager.swift # UNUserNotificationCenter fallback notification
├── Views/
│   ├── MainView.swift            # Home screen: time + ramp rows + diagnostics disclosure
│   ├── TimePickerSheet.swift     # Alarm time picker
│   ├── RampPickerSheet.swift     # Ramp duration picker
│   └── FiringView.swift          # Full-screen "alarm is ringing" screen
├── Resources/
│   └── ocean-waves.wav           # Bundled looping alarm sound
└── Assets.xcassets
```

## Key components

- **`Alarm`** — `Codable` struct holding `timeHour`, `timeMinute`, and `rampMinutes`. Computes `nextFireDate` (today if the time hasn't passed, otherwise tomorrow) and `rampStartDate`. Persists itself to `UserDefaults` under the `alarm.v1` key.
- **`AlarmStore`** — `@MainActor` `ObservableObject` that owns the current `Alarm`, `isAlarmFiring`, and persisted diagnostics. Every mutation (`updateTime`, `updateRamp`, `stopAlarm`) triggers a full reschedule: cancel fallback notification, stop/re-arm the audio player, and re-register the fallback notification.
- **`AudioRampPlayer`** — Singleton wrapping `AVAudioPlayer`. `arm(for:)` starts the audio at volume 0 immediately so the audio session stays active; a timer drives the volume ramp from wall-clock time. It also observes audio-session interruptions, route changes, and media-service resets to rebuild or resume the current armed occurrence when possible.
- **`AlarmDiagnostics`** — Small codable record stored in `UserDefaults` with the last armed time, fire date, ramp start, stop time, interruptions, route changes, media-service resets, and recovery outcome.
- **`NotificationManager`** — Requests notification permission on demand, schedules a single `UNTimeIntervalNotificationTrigger` at the alarm time as a backstop, and acts as `UNUserNotificationCenterDelegate` so the banner and sound still present when the app is foregrounded.

## Requirements

- Xcode 15+
- iOS 17+ target (uses `NavigationStack`, `@MainActor` on `ObservableObject`, `fullScreenCover`)
- A physical device is recommended for testing — the Simulator's background audio / notification behavior doesn't fully mirror a real iPhone.

## Running

1. Open `Gradual-Alarm.xcodeproj` in Xcode.
2. Select an iOS Simulator or a connected device.
3. Build & run (`⌘R`).
4. On first launch the app will request notification permission; grant it so the fallback notification can fire.

## Notes / caveats

- The app relies on a continuously-running `AVAudioPlayer` to keep the playback session alive until the ramp starts. The user should make sure the **media volume is turned up before going to sleep**.
- The bundled loop is `ocean-waves.wav` in `Resources/`.
- State persistence is intentionally lightweight: a single `Alarm` blob in `UserDefaults`. There is no multi-alarm support.
- Background audio reliability is improved with session recovery and diagnostics, but a powered-down phone still cannot alarm and a local notification remains only a fallback path.
