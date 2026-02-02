import CoreHaptics
import Foundation
import UIKit

final class HapticsEngine {
    private var engine: CHHapticEngine?
    private var player: CHHapticPatternPlayer?
    private let fallback = UINotificationFeedbackGenerator()
    private var hapticTimer: Timer?

    func startEscalationHaptics() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                engine = try CHHapticEngine()
                try engine?.start()
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
                    ],
                    relativeTime: 0
                )
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                player = try engine?.makePlayer(with: pattern)
                try player?.start(atTime: 0)

                hapticTimer?.invalidate()
                hapticTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    try? self?.player?.start(atTime: 0)
                }
            } catch {
                fallback.notificationOccurred(.warning)
            }
        } else {
            fallback.notificationOccurred(.warning)
        }
    }

    func stop() {
        hapticTimer?.invalidate()
        hapticTimer = nil
        try? player?.stop(atTime: 0)
        engine?.stop(completionHandler: nil)
        engine = nil
        player = nil
    }
}
