import Foundation

struct Alarm: Codable {
    var timeHour: Int
    var timeMinute: Int
    var rampMinutes: Int

    static let `default` = Alarm(timeHour: 7, timeMinute: 0, rampMinutes: 10)
    static let rampRange = 1...30

    // Next calendar occurrence of the alarm time (today if not yet passed, tomorrow if it has)
    var nextFireDate: Date {
        let cal = Calendar.current
        var components = cal.dateComponents([.year, .month, .day], from: Date())
        components.hour = timeHour
        components.minute = timeMinute
        components.second = 0
        let candidate = cal.date(from: components)!
        if candidate > Date() {
            return candidate
        }
        return cal.date(byAdding: .day, value: 1, to: candidate)!
    }

    // When to begin playing the silent loop: ramp duration + 5-min buffer before alarm time
    var silentLoopStartDate: Date {
        nextFireDate.addingTimeInterval(-Double(rampMinutes * 60) - 5 * 60)
    }

    // When to begin the audible volume ramp
    var rampStartDate: Date {
        nextFireDate.addingTimeInterval(-Double(rampMinutes * 60))
    }
}

extension Alarm {
    private static let key = "alarm.v1"

    static func load() -> Alarm {
        guard let data = UserDefaults.standard.data(forKey: key),
              let alarm = try? JSONDecoder().decode(Alarm.self, from: data) else {
            return .default
        }
        return alarm
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Alarm.key)
    }
}
