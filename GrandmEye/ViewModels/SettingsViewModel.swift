import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var appSettings: AppSettings {
        didSet { appSettings.save() }
    }
    
    @Published var magSettings: MagnificationSettings {
        didSet { magSettings.save() }
    }
    
    /// Supported languages for the picker.
    let languages = [
        (name: "Italiano", code: "it"),
        (name: "English", code: "en")
    ]
    
    init() {
        self.appSettings = AppSettings.load()
        self.magSettings = MagnificationSettings.load()
    }
    
    func resetAllSettings() {
        appSettings = AppSettings()
        magSettings = MagnificationSettings()
        appSettings.save()
        magSettings.save()
    }
    
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Version \(version)"
    }
}
