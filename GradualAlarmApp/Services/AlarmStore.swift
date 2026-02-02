import Foundation

struct AlarmStore {
    private let key = "alarm_config"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AlarmConfig {
        guard let data = defaults.data(forKey: key) else {
            return AlarmConfig.default()
        }
        do {
            return try JSONDecoder().decode(AlarmConfig.self, from: data)
        } catch {
            return AlarmConfig.default()
        }
    }

    func save(_ config: AlarmConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            defaults.set(data, forKey: key)
        } catch {
            defaults.removeObject(forKey: key)
        }
    }
}
