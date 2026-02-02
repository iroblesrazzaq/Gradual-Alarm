import AVFoundation
import Foundation

final class AudioRampEngine {
    private var gentlePlayer: AVAudioPlayer?
    private var loudPlayer: AVAudioPlayer?
    private var rampTimer: Timer?
    private let session = AVAudioSession.sharedInstance()
    private let toneFrequencies: [String: Double] = [
        "birds": 440,
        "chimes": 523.25,
        "breeze": 392,
        "dawn": 330,
        "piano": 262,
        "loud_alarm": 880
    ]

    func configureSession() {
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Best effort; if session fails audio may still play with defaults.
        }
    }

    func startRamp(fadeStart: Date, fireDate: Date, gentleSoundId: String, tick: @escaping (Float) -> Void, completion: @escaping () -> Void) {
        configureSession()
        gentlePlayer = makePlayer(for: gentleSoundId)
        gentlePlayer?.volume = 0.0
        gentlePlayer?.numberOfLoops = -1
        gentlePlayer?.play()

        rampTimer?.invalidate()
        rampTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            let now = Date()
            let total = max(1, fireDate.timeIntervalSince(fadeStart))
            let progress = max(0, min(1, now.timeIntervalSince(fadeStart) / total))
            let volume = Float(progress)
            self?.gentlePlayer?.volume = volume
            tick(volume)
            if now >= fireDate {
                self?.gentlePlayer?.volume = 1.0
                completion()
            }
        }
    }

    func escalate(loudSoundId: String) {
        gentlePlayer?.stop()
        gentlePlayer = nil
        loudPlayer = makePlayer(for: loudSoundId)
        loudPlayer?.volume = 1.0
        loudPlayer?.numberOfLoops = -1
        loudPlayer?.play()
    }

    func stopAll() {
        rampTimer?.invalidate()
        rampTimer = nil
        gentlePlayer?.stop()
        loudPlayer?.stop()
        gentlePlayer = nil
        loudPlayer = nil
    }

    private func makePlayer(for soundId: String) -> AVAudioPlayer? {
        let frequency = toneFrequencies[soundId] ?? 440
        guard let url = ToneGenerator.shared.toneURL(for: soundId, frequency: frequency) else {
            return nil
        }
        return try? AVAudioPlayer(contentsOf: url)
    }
}
