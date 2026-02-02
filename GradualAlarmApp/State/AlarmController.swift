import Foundation
import UserNotifications

@MainActor
final class AlarmController: ObservableObject {
    enum AlarmState: String {
        case idle
        case scheduled
        case ramping
        case ringing
        case escalating
    }

    @Published var config: AlarmConfig
    @Published var state: AlarmState = .idle
    @Published var nextFire: Date?
    @Published var fadeStart: Date?
    @Published var showingRinging = false
    @Published var selectedSoundName = "birds"

    private let store: AlarmStore
    private let scheduler: AlarmScheduler
    private let audio: AudioRampEngine
    private let haptics: HapticsEngine

    private var schedulerTimer: Timer?
    private var escalationTimer: Timer?

    init(
        store: AlarmStore = AlarmStore(),
        scheduler: AlarmScheduler = AlarmScheduler(),
        audio: AudioRampEngine = AudioRampEngine(),
        haptics: HapticsEngine = HapticsEngine()
    ) {
        self.store = store
        self.scheduler = scheduler
        self.audio = audio
        self.haptics = haptics
        self.config = store.load()
        self.selectedSoundName = config.soundId
        NotificationCenter.default.addObserver(
            forName: .alarmNotificationAction,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let actionId = notification.userInfo?[\"actionId\"] as? String
            self?.handleNotificationResponse(actionId: actionId)
        }
        rescheduleNext()
    }

    func requestPermissionsIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func saveAndReschedule() {
        config.soundId = selectedSoundName
        store.save(config)
        rescheduleNext()
    }

    func rescheduleNext() {
        if config.enabled {
            let fire = scheduler.computeNextFireDate(hour: config.hour, minute: config.minute)
            nextFire = fire
            fadeStart = scheduler.computeFadeStart(fireDate: fire, fadeMinutes: config.fadeMinutes)
            state = .scheduled
            Task {
                await scheduler.scheduleNotifications(fireDate: fire)
            }
            startSchedulerTick()
        } else {
            nextFire = nil
            fadeStart = nil
            state = .idle
            Task { await scheduler.cancelNotifications() }
            stopAllTimers()
        }
    }

    func startRampIfNeeded() {
        guard config.enabled, let fadeStart, let nextFire else { return }
        let now = Date()
        guard now >= fadeStart, state == .scheduled else { return }
        state = .ramping
        showingRinging = true
        audio.startRamp(fadeStart: fadeStart, fireDate: nextFire, gentleSoundId: config.soundId, tick: { _ in }, completion: { [weak self] in
            Task { @MainActor in
                self?.state = .ringing
                self?.scheduleEscalationTimer()
            }
        })
    }

    func dismiss() {
        audio.stopAll()
        haptics.stop()
        showingRinging = false
        escalationTimer?.invalidate()
        if config.enabled {
            rescheduleNext()
        } else {
            state = .idle
        }
    }

    func snooze() {
        audio.stopAll()
        haptics.stop()
        showingRinging = false
        escalationTimer?.invalidate()

        let snoozeMinutes = max(1, config.snoozeMinutes)
        let snoozeFire = Calendar.current.date(byAdding: .minute, value: snoozeMinutes, to: Date()) ?? Date()
        nextFire = snoozeFire
        let fadeMinutes = min(5, snoozeMinutes)
        fadeStart = scheduler.computeFadeStart(fireDate: snoozeFire, fadeMinutes: fadeMinutes)
        state = .scheduled
        Task { await scheduler.scheduleNotifications(fireDate: snoozeFire) }
        startSchedulerTick()
    }

    func handleNotificationResponse(actionId: String?) {
        switch actionId {
        case "DISMISS_ACTION":
            dismiss()
        case "SNOOZE_ACTION":
            snooze()
        default:
            if state == .scheduled {
                startRampIfNeeded()
            }
        }
    }

    func triggerImmediateRinging() {
        guard config.enabled else { return }
        showingRinging = true
        state = .ringing
        audio.startRamp(fadeStart: Date(), fireDate: Date(), gentleSoundId: config.soundId, tick: { _ in }, completion: { [weak self] in
            Task { @MainActor in
                self?.state = .ringing
                self?.scheduleEscalationTimer()
            }
        })
    }

    private func startSchedulerTick() {
        schedulerTimer?.invalidate()
        schedulerTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.startRampIfNeeded()
            }
        }
    }

    private func scheduleEscalationTimer() {
        escalationTimer?.invalidate()
        escalationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.state = .escalating
                self.audio.escalate(loudSoundId: "loud_alarm")
                self.haptics.startEscalationHaptics()
            }
        }
    }

    private func stopAllTimers() {
        schedulerTimer?.invalidate()
        schedulerTimer = nil
        escalationTimer?.invalidate()
        escalationTimer = nil
    }
}

extension Notification.Name {
    static let alarmNotificationAction = Notification.Name(\"AlarmNotificationAction\")
}
