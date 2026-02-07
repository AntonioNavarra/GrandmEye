//
//  EasyReaderApp.swift
//  EasyReader
//
//  Created by Antonio Navarra on 24/11/25.
//

import SwiftUI

@main
struct EasyReaderApp: App {
    init() {
        let settings = AppSettings.load()
        Task { @MainActor in
            AudioManager.shared.configure(enabled: settings.soundEnabled, volume: settings.soundVolume)
            HapticManager.shared.setEnabled(settings.hapticEnabled)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            CameraView()
                .preferredColorScheme(.dark)
        }
    }
}
