import Foundation
import SwiftUI

/// App preferences and persistence.
struct AppSettings: Codable {
    var soundEnabled: Bool = true
    var hapticEnabled: Bool = true
    var soundVolume: Float = 0.7
    
    /// Stored language code (e.g., "en" or "it").
    var languageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    /// Returns a Foundation Locale for SwiftUI environment injection.
    var locale: Locale {
        return Locale(identifier: languageCode)
    }
    
    private static let key = "appSettings"
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.key)
        }
    }
    
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return decoded
    }
}
