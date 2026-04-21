import Foundation

struct AlarmDiagnostics: Codable {
    var lastArmedAt: Date?
    var lastFireDate: Date?
    var lastRampStartedAt: Date?
    var lastStopAt: Date?
    var lastInterruptionBeganAt: Date?
    var lastInterruptionEndedAt: Date?
    var lastRouteChangeAt: Date?
    var lastMediaServicesResetAt: Date?
    var lastRecoveryAttemptAt: Date?
    var lastRecoveryOutcome: String?

    static let empty = AlarmDiagnostics()
}

enum AlarmDiagnosticsStore {
    private static let key = "alarm.diagnostics.v1"

    static func load() -> AlarmDiagnostics {
        guard let data = UserDefaults.standard.data(forKey: key),
              let diagnostics = try? JSONDecoder().decode(AlarmDiagnostics.self, from: data) else {
            return .empty
        }
        return diagnostics
    }

    static func save(_ diagnostics: AlarmDiagnostics) {
        guard let data = try? JSONEncoder().encode(diagnostics) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    @discardableResult
    static func update(_ mutate: (inout AlarmDiagnostics) -> Void) -> AlarmDiagnostics {
        var diagnostics = load()
        mutate(&diagnostics)
        save(diagnostics)
        return diagnostics
    }
}
