import Foundation

/// Handles general application preferences.
struct AppSettings: Codable, Sendable {
    var soundEnabled: Bool = true
    var hapticEnabled: Bool = true
    var soundVolume: Float = 0.7
    var highContrastEnabled: Bool = false
    var nightModeEnabled: Bool = false
    
    private static let userDefaultsKey = "appSettings"
    
    static func load() -> AppSettings {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return decoded
        }
        return AppSettings()
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
        }
    }
    
    static func reset() -> AppSettings {
        let defaults = AppSettings()
        defaults.save()
        return defaults
    }
}
