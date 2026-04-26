import Foundation

enum AlarmSound: String, CaseIterable, Codable, Identifiable {
    case oceanWaves = "ocean-waves"
    case morningBirds = "morning-birds"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oceanWaves:
            return "Ocean waves"
        case .morningBirds:
            return "Morning birds"
        }
    }

    var resourceName: String { rawValue }
}

enum AlarmRampCurve: String, CaseIterable, Codable, Identifiable {
    case linear
    case easeIn
    case easeOut
    case easeInOut

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .linear:
            return "Linear"
        case .easeIn:
            return "Gentle start"
        case .easeOut:
            return "Fast start"
        case .easeInOut:
            return "Smooth"
        }
    }

    func apply(to progress: Double) -> Double {
        let p = min(max(progress, 0), 1)
        switch self {
        case .linear:
            return p
        case .easeIn:
            return p * p
        case .easeOut:
            return 1 - pow(1 - p, 2)
        case .easeInOut:
            return p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
        }
    }
}

struct Alarm: Codable {
    var timeHour: Int
    var timeMinute: Int
    var rampMinutes: Int
    var repeatWeekdays: Set<Int>
    var skippedFireDate: Date?
    var sound: AlarmSound
    var peakVolume: Float
    var rampCurve: AlarmRampCurve
    var nudgeEnabled: Bool
    var nudgeMinutes: Int

    static let allWeekdays = Set(1...7)
    static let `default` = Alarm(
        timeHour: 7,
        timeMinute: 0,
        rampMinutes: 10,
        repeatWeekdays: allWeekdays,
        skippedFireDate: nil,
        sound: .oceanWaves,
        peakVolume: 1,
        rampCurve: .linear,
        nudgeEnabled: false,
        nudgeMinutes: 10
    )
    static let rampRange = 1...30
    static let nudgeRange = 5...30

    init(
        timeHour: Int,
        timeMinute: Int,
        rampMinutes: Int,
        repeatWeekdays: Set<Int> = Alarm.allWeekdays,
        skippedFireDate: Date? = nil,
        sound: AlarmSound = .oceanWaves,
        peakVolume: Float = 1,
        rampCurve: AlarmRampCurve = .linear,
        nudgeEnabled: Bool = false,
        nudgeMinutes: Int = 10
    ) {
        self.timeHour = timeHour
        self.timeMinute = timeMinute
        self.rampMinutes = Self.clamp(rampMinutes, to: Self.rampRange)
        self.repeatWeekdays = Self.sanitizedWeekdays(repeatWeekdays)
        self.skippedFireDate = skippedFireDate
        self.sound = sound
        self.peakVolume = Self.clamp(peakVolume, min: 0.1, max: 1)
        self.rampCurve = rampCurve
        self.nudgeEnabled = nudgeEnabled
        self.nudgeMinutes = Self.clamp(nudgeMinutes, to: Self.nudgeRange)
    }

    enum CodingKeys: String, CodingKey {
        case timeHour
        case timeMinute
        case rampMinutes
        case repeatWeekdays
        case skippedFireDate
        case sound
        case peakVolume
        case rampCurve
        case nudgeEnabled
        case nudgeMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            timeHour: try container.decodeIfPresent(Int.self, forKey: .timeHour) ?? Self.default.timeHour,
            timeMinute: try container.decodeIfPresent(Int.self, forKey: .timeMinute) ?? Self.default.timeMinute,
            rampMinutes: try container.decodeIfPresent(Int.self, forKey: .rampMinutes) ?? Self.default.rampMinutes,
            repeatWeekdays: try container.decodeIfPresent(Set<Int>.self, forKey: .repeatWeekdays) ?? Self.allWeekdays,
            skippedFireDate: try container.decodeIfPresent(Date.self, forKey: .skippedFireDate),
            sound: try container.decodeIfPresent(AlarmSound.self, forKey: .sound) ?? Self.default.sound,
            peakVolume: try container.decodeIfPresent(Float.self, forKey: .peakVolume) ?? Self.default.peakVolume,
            rampCurve: try container.decodeIfPresent(AlarmRampCurve.self, forKey: .rampCurve) ?? Self.default.rampCurve,
            nudgeEnabled: try container.decodeIfPresent(Bool.self, forKey: .nudgeEnabled) ?? Self.default.nudgeEnabled,
            nudgeMinutes: try container.decodeIfPresent(Int.self, forKey: .nudgeMinutes) ?? Self.default.nudgeMinutes
        )
    }

    // Next calendar occurrence of the alarm time (today if not yet passed, tomorrow if it has)
    var nextFireDate: Date {
        fireDate(after: Date())
    }

    func fireDate(after referenceDate: Date) -> Date {
        var searchDate = referenceDate

        for _ in 0..<16 {
            guard let candidate = nextMatchingFireDate(after: searchDate) else { break }

            if let skippedFireDate, Calendar.current.isDate(candidate, equalTo: skippedFireDate, toGranularity: .minute) {
                searchDate = candidate.addingTimeInterval(60)
                continue
            }

            return candidate
        }

        return referenceDate.addingTimeInterval(24 * 60 * 60)
    }

    // When to begin the audible volume ramp
    var rampStartDate: Date {
        nextFireDate.addingTimeInterval(-Double(rampMinutes * 60))
    }

    func rampStartDate(for fireDate: Date) -> Date {
        fireDate.addingTimeInterval(-Double(rampMinutes * 60))
    }

    var nudgeFireDate: Date? {
        nudgeFireDate(for: nextFireDate)
    }

    func nudgeFireDate(for fireDate: Date) -> Date? {
        guard nudgeEnabled else { return nil }
        return fireDate.addingTimeInterval(Double(nudgeMinutes * 60))
    }

    var repeatSummary: String {
        let weekdays = repeatWeekdays
        if weekdays == Self.allWeekdays {
            return "Every day"
        }
        if weekdays == Set([2, 3, 4, 5, 6]) {
            return "Weekdays"
        }
        if weekdays == Set([1, 7]) {
            return "Weekends"
        }

        let symbols = Calendar.current.shortWeekdaySymbols
        return weekdays.sorted().compactMap { weekday in
            guard symbols.indices.contains(weekday - 1) else { return nil }
            return symbols[weekday - 1]
        }.joined(separator: ", ")
    }

    func clearingExpiredSkip(after referenceDate: Date = Date()) -> Alarm {
        guard let skippedFireDate, skippedFireDate < referenceDate.addingTimeInterval(-60) else {
            return self
        }
        var alarm = self
        alarm.skippedFireDate = nil
        return alarm
    }

    private func nextMatchingFireDate(after referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        var bestDate: Date?

        for weekday in repeatWeekdays.sorted() {
            var components = DateComponents()
            components.calendar = calendar
            components.weekday = weekday
            components.hour = timeHour
            components.minute = timeMinute
            components.second = 0

            guard let candidate = calendar.nextDate(
                after: referenceDate,
                matching: components,
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            ) else {
                continue
            }

            if bestDate == nil || candidate < bestDate! {
                bestDate = candidate
            }
        }

        return bestDate
    }

    private static func sanitizedWeekdays(_ weekdays: Set<Int>) -> Set<Int> {
        let valid = weekdays.filter { allWeekdays.contains($0) }
        return valid.isEmpty ? allWeekdays : valid
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func clamp(_ value: Float, min lowerBound: Float, max upperBound: Float) -> Float {
        Swift.min(Swift.max(value, lowerBound), upperBound)
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
