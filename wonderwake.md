# WonderWake Notes

## Purpose
Working notes on WonderWake's UX flow and visible feature set so we can sketch how the product behaves and later infer likely implementation decisions.

## Setup Flow
Observed onboarding/setup sequence:

1. On app setup, WonderWake asks iOS for permission to schedule alarms and timers.
2. The system copy indicates this should work even if Focus is active.
3. After that, WonderWake asks for standard notification permission.

## Notable Features
- `Nudge` as a secondary, harsher backup alarm if the first alarm is not responded to.
- Configurable snooze duration.
- iPhone alarm backup so that if WonderWake is interrupted, the built-in iPhone alarm is still set and goes off.
- Peak alarm volume setting.
- Randomized wake-up melody feature.
  - Marked as lower priority for our product analysis.

## Product Implications
- WonderWake appears to position alarm delivery as more than a single notification path.
- The explicit system prompt about alarms/timers suggests reliance on newer iOS alarm/timer capabilities in addition to standard notification permission.
- The iPhone alarm backup feature suggests a deliberate redundancy strategy rather than trusting only the app's primary alarm path.
- `Nudge` indicates a two-stage wake flow:
  - primary gradual wake
  - secondary harsher escalation if the user does not respond

## Follow-Up Questions For Reverse Engineering
- What exact iOS entitlement or permission wording appears in the alarm/timer prompt?
- When does WonderWake ask for the iPhone backup alarm setup?
- Does `Nudge` trigger after a fixed delay or after missed user interaction?
- Is peak alarm volume a cap on the app's playback volume ramp, or does it try to influence broader device audio behavior?
- How is snooze surfaced:
  - during onboarding
  - in settings
  - on the live alarm screen
