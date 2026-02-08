import SwiftUI

@main
struct GrandmEye: App {
    /// Observes settings changes in storage to refresh environment locale.
    @AppStorage("appSettings") var settingsData: Data?
    
    var appSettings: AppSettings {
        if let data = settingsData,
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return decoded
        }
        return AppSettings()
    }
    
    var body: some Scene {
        WindowGroup {
            CameraView()
                // Dynamically inject the saved locale into the whole environment
                .environment(\.locale, appSettings.locale)
                .preferredColorScheme(.dark)
        }
    }
}
