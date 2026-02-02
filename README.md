# Gradual Ramp Alarm (MVP)

Single-alarm iOS app that ramps synthesized tones from silence to full volume by your wake time, then escalates to a loud alarm tone + haptics after 60 seconds if not dismissed.

## Requirements
- Xcode (latest stable)
- iOS 16.0+ simulator or device

## Build & Run
1. Open `GradualAlarmApp.xcodeproj` in Xcode.
2. Select an iOS Simulator or connected device.
3. Build and run.

## Quick Test
1. Set the alarm time 2 minutes ahead.
2. Set fade minutes to 1.
3. Save the alarm and lock the screen.
4. You should hear the gentle ramp start at `T - 1 min`, reach full volume at `T`, then switch to the loud alarm + haptics at `T + 60s` if not dismissed.

Use **Test Ramp (15s)** inside the app to trigger a fast ramp for manual verification.

## iOS Limitations
- The app cannot force the system volume; it scales app audio only.
- Local notifications may be silenced by Focus modes.
- Background execution is best-effort; notifications are the failsafe when the app is not running.
- Alarm sounds are generated at runtime (no bundled audio assets).

## Project Structure
```
GradualAlarmApp/
  GradualAlarmApp.swift
  AppDelegate.swift
  Models/
    AlarmConfig.swift
  Services/
    AlarmStore.swift
    AlarmScheduler.swift
    AudioRampEngine.swift
    ToneGenerator.swift
    HapticsEngine.swift
  State/
    AlarmController.swift
  Views/
    OnboardingView.swift
    MainAlarmView.swift
    SoundPickerView.swift
    RingingView.swift
  Resources/
```
