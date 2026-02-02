import Foundation

struct AlarmConfig: Codable, Equatable {
    var enabled: Bool
    var hour: Int
    var minute: Int
    var fadeMinutes: Int
    var soundId: String
    var snoozeEnabled: Bool
    var snoozeMinutes: Int

    static func `default`(now: Date = Date(), calendar: Calendar = .current) -> AlarmConfig {
        let rounded = calendar.date(byAdding: .minute, value: 10, to: now) ?? now
        let components = calendar.dateComponents([.hour, .minute], from: rounded)
        return AlarmConfig(
            enabled: false,
            hour: components.hour ?? 7,
            minute: components.minute ?? 0,
            fadeMinutes: 5,
            soundId: "birds",
            snoozeEnabled: true,
            snoozeMinutes: 9
        )
    }
}
