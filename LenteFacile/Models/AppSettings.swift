//
//  File.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 24/11/25.
//

import Foundation

/// Modello per le impostazioni generali dell'applicazione.
/// Gestisce preferenze audio, tattili e visive.
struct AppSettings: Codable, Sendable {
    // MARK: - Properties
    var soundEnabled: Bool = true
    var hapticEnabled: Bool = true
    var soundVolume: Float = 0.7
    
    // Accessibility / Visual settings
    var highContrastEnabled: Bool = false
    var nightModeEnabled: Bool = false // Può essere usata per invertire colori o applicare filtri rossi
    
    // MARK: - Constants
    private static let userDefaultsKey = "appSettings"
    
    // MARK: - Persistence
    
    /// Carica le impostazioni da UserDefaults o restituisce i default.
    static func load() -> AppSettings {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return decoded
        }
        return AppSettings()
    }
    
    /// Salva lo stato corrente in UserDefaults.
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
        }
    }
    
    /// Ripristina ai valori di fabbrica
    static func reset() -> AppSettings {
        let defaults = AppSettings()
        defaults.save()
        return defaults
    }
}
