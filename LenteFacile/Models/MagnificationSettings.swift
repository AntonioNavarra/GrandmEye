//
//  MagnificationSettings.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 24/11/25.
//

import Foundation
import CoreGraphics

/// Modello per le impostazioni specifiche dello zoom e della fotocamera.
struct MagnificationSettings: Codable, Sendable {
    // MARK: - Properties
    var defaultZoomLevel: CGFloat = 2.5
    var minZoomLevel: CGFloat = 1.0
    var maxZoomLevel: CGFloat = 10.0
    var zoomStep: CGFloat = 0.1
    
    /// Se true, l'app si apre con l'ultimo livello di zoom utilizzato
    var rememberLastZoom: Bool = true
    
    /// L'ultimo livello di zoom impostato dall'utente (opzionale)
    var lastUsedZoom: CGFloat?
    
    // MARK: - Constants
    private static let userDefaultsKey = "magnificationSettings"
    
    // MARK: - Computed Properties
    
    /// Determina il livello di zoom iniziale all'avvio dell'app.
    var startingZoom: CGFloat {
        if rememberLastZoom, let last = lastUsedZoom {
            return clampedZoom(last)
        }
        return defaultZoomLevel
    }
    
    /// Restituisce il range chiuso per l'utilizzo negli Slider SwiftUI.
    var zoomRange: ClosedRange<CGFloat> {
        minZoomLevel...maxZoomLevel
    }
    
    // MARK: - Logic
    
    /// Assicura che un valore di zoom rispetti i limiti min/max definiti.
    func clampedZoom(_ level: CGFloat) -> CGFloat {
        return min(max(level, minZoomLevel), maxZoomLevel)
    }
    
    /// Aggiorna l'ultimo zoom usato e salva automaticamente se richiesto.
    mutating func updateLastUsedZoom(_ level: CGFloat) {
        self.lastUsedZoom = clampedZoom(level)
    }
    
    // MARK: - Persistence
    
    static func load() -> MagnificationSettings {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(MagnificationSettings.self, from: data) {
            return decoded
        }
        return MagnificationSettings()
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
        }
    }
}
