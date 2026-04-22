import AVFoundation
import Foundation

enum AlarmPlaybackPhase: String {
    case idle
    case silentHold
    case ramping
}

@MainActor
final class AudioRampPlayer: NSObject {
    static let shared = AudioRampPlayer()

    var onStateChanged: (() -> Void)?
    var isArmed: Bool { player != nil }
    var currentFireDate: Date? { armedFireDate }
    var currentPhase: AlarmPlaybackPhase { playbackPhase }
    var diagnostics: AlarmDiagnostics { AlarmDiagnosticsStore.load() }

    private var player: AVAudioPlayer?
    private var rampStartTimer: Timer?
    private var rampTimer: Timer?
    private var armedFireDate: Date?
    private var armedRampStartDate: Date?
    private var playbackPhase: AlarmPlaybackPhase = .idle
    private var isInterrupted = false

    private override init() {
        super.init()
        registerSessionObservers()
    }

    func arm(for alarm: Alarm, fireDate: Date? = nil) {
        stop(deactivateSession: false)

        guard let audioURL = Bundle.main.url(forResource: "ocean-waves", withExtension: "wav") else {
            print("AudioRampPlayer: missing bundled ocean-waves.wav resource")
            recordRecoveryOutcome("missing_audio_resource")
            return
        }

        do {
            try configureSessionForPlayback()

            let player = try AVAudioPlayer(contentsOf: audioURL)
            player.numberOfLoops = -1
            player.volume = 0
            player.prepareToPlay()

            self.player = player
            let fireDate = fireDate ?? alarm.nextFireDate
            let rampStartDate = alarm.rampStartDate(for: fireDate)
            self.armedFireDate = fireDate
            self.armedRampStartDate = rampStartDate
            self.isInterrupted = false

            _ = AlarmDiagnosticsStore.update { diagnostics in
                diagnostics.lastArmedAt = Date()
                diagnostics.lastFireDate = fireDate
            }

            guard player.play() else {
                print("AudioRampPlayer: failed to start silent playback")
                stop()
                return
            }

            beginRampIfNeeded()
        } catch {
            print("AudioRampPlayer: failed to arm alarm: \(error.localizedDescription)")
            recordRecoveryOutcome("arm_failed")
            stop()
        }
    }

    func stop(recordStopAt: Bool = false) {
        stop(deactivateSession: true)

        if recordStopAt {
            _ = AlarmDiagnosticsStore.update { diagnostics in
                diagnostics.lastStopAt = Date()
            }
        }
    }

    func syncForCurrentTime() {
        guard isArmed else {
            updatePhase(.idle)
            return
        }

        if isInterrupted {
            recoverPlaybackForCurrentTime(outcomeOnSuccess: "scene_phase_catchup_success", outcomeOnFailure: "scene_phase_catchup_failed")
            return
        }

        beginRampIfNeeded()
        updateRampVolume()
    }

    func resumeAfterInterruptionIfNeeded() {
        guard isArmed else {
            recordRecoveryOutcome("resume_skipped_not_armed")
            return
        }

        recoverPlaybackForCurrentTime(outcomeOnSuccess: "resume_success", outcomeOnFailure: "resume_failed")
    }

    func rebuildAfterMediaServicesReset() {
        guard let fireDate = armedFireDate else {
            recordRecoveryOutcome("reset_skipped_not_armed")
            return
        }

        _ = AlarmDiagnosticsStore.update { diagnostics in
            diagnostics.lastMediaServicesResetAt = Date()
            diagnostics.lastRecoveryAttemptAt = Date()
        }

        let previousPhase = playbackPhase
        guard let audioURL = Bundle.main.url(forResource: "ocean-waves", withExtension: "wav") else {
            recordRecoveryOutcome("reset_missing_audio_resource")
            return
        }

        do {
            try configureSessionForPlayback()

            let replacementPlayer = try AVAudioPlayer(contentsOf: audioURL)
            replacementPlayer.numberOfLoops = -1
            replacementPlayer.volume = previousPhase == .ramping ? currentVolume(for: Date()) : 0
            replacementPlayer.prepareToPlay()

            player?.stop()
            player = replacementPlayer
            armedRampStartDate = armedRampStartDate ?? fireDate.addingTimeInterval(-Double(max(1, 60)))
            isInterrupted = false

            guard replacementPlayer.play() else {
                recordRecoveryOutcome("reset_play_failed")
                return
            }

            beginRampIfNeeded()
            updateRampVolume()
            recordRecoveryOutcome("reset_success")
        } catch {
            print("AudioRampPlayer: failed to rebuild after media services reset: \(error.localizedDescription)")
            recordRecoveryOutcome("reset_failed")
        }
    }

    private func stop(deactivateSession: Bool) {
        rampStartTimer?.invalidate()
        rampStartTimer = nil

        rampTimer?.invalidate()
        rampTimer = nil

        player?.stop()
        player = nil

        armedFireDate = nil
        armedRampStartDate = nil
        isInterrupted = false
        updatePhase(.idle)

        guard deactivateSession else { return }

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("AudioRampPlayer: failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    @objc private func handleRampStartTimer() {
        beginRampIfNeeded()
    }

    @objc private func updateRampVolume() {
        guard let player, let rampStartDate = armedRampStartDate, let fireDate = armedFireDate else {
            stop(deactivateSession: true)
            return
        }

        let elapsed = Date().timeIntervalSince(rampStartDate)
        let total = fireDate.timeIntervalSince(rampStartDate)
        guard total > 0 else {
            player.volume = 1
            updatePhase(.ramping)
            rampTimer?.invalidate()
            rampTimer = nil
            return
        }

        player.volume = currentVolume(for: Date())

        if elapsed >= total {
            rampTimer?.invalidate()
            rampTimer = nil
        }
    }

    private func beginRampIfNeeded() {
        guard let player else { return }
        guard let rampStartDate = armedRampStartDate else { return }

        if Date() < rampStartDate {
            player.volume = 0
            updatePhase(.silentHold)
            scheduleRampStartTimer(for: rampStartDate)
            return
        }

        rampStartTimer?.invalidate()
        rampStartTimer = nil
        updatePhase(.ramping)
        _ = AlarmDiagnosticsStore.update { diagnostics in
            diagnostics.lastRampStartedAt = Date()
            diagnostics.lastFireDate = armedFireDate
        }
        ensureRampTimer()
        updateRampVolume()
    }

    private func ensureRampTimer() {
        guard rampTimer == nil else { return }
        let timer = Timer(timeInterval: 0.5, target: self, selector: #selector(updateRampVolume), userInfo: nil, repeats: true)
        rampTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func scheduleRampStartTimer(for date: Date) {
        guard rampStartTimer == nil else { return }
        let timer = Timer(
            fireAt: date,
            interval: 0,
            target: self,
            selector: #selector(handleRampStartTimer),
            userInfo: nil,
            repeats: false
        )
        rampStartTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func configureSessionForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
    }

    private func currentVolume(for now: Date) -> Float {
        guard let rampStartDate = armedRampStartDate, let fireDate = armedFireDate else { return 0 }
        let elapsed = now.timeIntervalSince(rampStartDate)
        let total = fireDate.timeIntervalSince(rampStartDate)
        guard total > 0 else { return 1 }
        let progress = min(max(elapsed / total, 0), 1)
        return Float(progress)
    }

    private func updatePhase(_ phase: AlarmPlaybackPhase) {
        guard playbackPhase != phase else { return }
        playbackPhase = phase
        notifyStateChanged()
    }

    private func notifyStateChanged() {
        onStateChanged?()
    }

    private func recordRecoveryOutcome(_ outcome: String) {
        _ = AlarmDiagnosticsStore.update { diagnostics in
            diagnostics.lastRecoveryOutcome = outcome
        }
        notifyStateChanged()
    }

    private func registerSessionObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        center.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: session)
        center.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: session)
        center.addObserver(self, selector: #selector(handleMediaServicesReset), name: AVAudioSession.mediaServicesWereResetNotification, object: session)
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeRawValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRawValue) else {
            return
        }

        switch type {
        case .began:
            isInterrupted = true
            rampTimer?.invalidate()
            rampTimer = nil
            _ = AlarmDiagnosticsStore.update { diagnostics in
                diagnostics.lastInterruptionBeganAt = Date()
                diagnostics.lastAudioLossAt = Date()
            }
            notifyStateChanged()

        case .ended:
            _ = AlarmDiagnosticsStore.update { diagnostics in
                diagnostics.lastInterruptionEndedAt = Date()
            }

            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                resumeAfterInterruptionIfNeeded()
            } else {
                recoverPlaybackForCurrentTime(
                    outcomeOnSuccess: "resume_success_without_shouldResume",
                    outcomeOnFailure: "resume_failed_without_shouldResume"
                )
            }

        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        _ = AlarmDiagnosticsStore.update { diagnostics in
            diagnostics.lastRouteChangeAt = Date()
        }

        guard isArmed else {
            notifyStateChanged()
            return
        }

        if isInterrupted || player?.isPlaying == false {
            _ = AlarmDiagnosticsStore.update { diagnostics in
                diagnostics.lastRecoveryAttemptAt = Date()
            }
            recoverPlaybackForCurrentTime(
                outcomeOnSuccess: "route_change_recovery_success",
                outcomeOnFailure: "route_change_recovery_failed"
            )
        } else {
            notifyStateChanged()
        }
    }

    @objc private func handleMediaServicesReset() {
        rebuildAfterMediaServicesReset()
    }

    private func recoverPlaybackForCurrentTime(outcomeOnSuccess: String, outcomeOnFailure: String) {
        guard isArmed else {
            recordRecoveryOutcome("resume_skipped_not_armed")
            return
        }

        _ = AlarmDiagnosticsStore.update { diagnostics in
            diagnostics.lastRecoveryAttemptAt = Date()
        }

        do {
            try configureSessionForPlayback()

            if let player, !player.isPlaying {
                guard player.play() else {
                    recordRecoveryOutcome("\(outcomeOnFailure)_play_failed")
                    return
                }
            }

            isInterrupted = false
            beginRampIfNeeded()
            updateRampVolume()
            recordRecoveryOutcome(outcomeOnSuccess)
        } catch {
            print("AudioRampPlayer: failed to recover playback: \(error.localizedDescription)")
            recordRecoveryOutcome(outcomeOnFailure)
        }
    }
}
