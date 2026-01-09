//
//  SettingsViewModel.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 25/11/25.
//

import SwiftUI
import Combine

/// ViewModel per la gestione delle preferenze utente.
/// Aggiorna i modelli persistenti (AppSettings, MagnificationSettings) e notifica la UI.
@MainActor
final class SettingsViewModel: ObservableObject {
    
    // MARK: - Published Settings
    // Usiamo property observer per salvare automaticamente al cambio
    
    @Published var appSettings: AppSettings {
        didSet {
            appSettings.save()
            updateManagers()
        }
    }
    
    @Published var magSettings: MagnificationSettings {
        didSet {
            magSettings.save()
        }
    }
    
    // MARK: - Init
    init() {
        self.appSettings = AppSettings.load()
        self.magSettings = MagnificationSettings.load()
    }
    
    // MARK: - Actions
    
    /// Aggiorna i manager singleton in tempo reale quando cambiano le impostazioni
    private func updateManagers() {
        HapticManager.shared.setEnabled(appSettings.hapticEnabled)
        AudioManager.shared.configure(enabled: appSettings.soundEnabled, volume: appSettings.soundVolume)
    }
    
    /// Ripristina tutte le impostazioni ai valori di fabbrica
    func resetAllSettings() {
        // Reset AppSettings
        appSettings = AppSettings.reset()
        
        // Reset MagnificationSettings
        let defaultMag = MagnificationSettings()
        defaultMag.save()
        magSettings = defaultMag
        
        // Feedback
        HapticManager.shared.success()
        AudioManager.shared.playSaveSuccess()
    }
    
    /// Formatta il numero di versione dell'app
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Versione \(version) (\(build))"
    }
}
