//
//  HapticManager.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 24/11/25.
//

import UIKit

/// Gestore centralizzato per il feedback tattile (Haptics).
/// Implementato come Singleton MainActor per interagire con UIKit.
@MainActor
final class HapticManager {
    
    // MARK: - Singleton
    static let shared = HapticManager()
    
    // MARK: - Properties
    private var isEnabled: Bool = true
    
    // Generators (Lazy initialization per performance)
    private var impactGeneratorMedium: UIImpactFeedbackGenerator?
    private var impactGeneratorLight: UIImpactFeedbackGenerator?
    private var notificationGenerator: UINotificationFeedbackGenerator?
    private var selectionGenerator: UISelectionFeedbackGenerator?
    
    private init() {}
    
    // MARK: - Configuration
    
    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }
    
    // MARK: - Haptic Methods
    
    /// Feedback leggero per tap generici
    func buttonTap() {
        guard isEnabled else { return }
        playImpact(style: .light)
    }
    
    /// Alias per buttonTap, usato negli slider
    func sliderTap() {
        buttonTap()
    }
    
    /// Feedback deciso per azioni primarie
    func primaryButtonTap() {
        guard isEnabled else { return }
        playImpact(style: .medium)
    }
    
    /// Feedback standard per cambio selezione (es. Slider drag)
    func selectionChanged() {
        guard isEnabled else { return }
        if selectionGenerator == nil {
            selectionGenerator = UISelectionFeedbackGenerator()
        }
        selectionGenerator?.prepare()
        selectionGenerator?.selectionChanged()
    }
    
    /// Alias per selectionChanged per chiarezza
    func sliderTick() {
        selectionChanged()
    }
    
    /// Feedback per cambio valore significativo (es. numeri interi)
    func valueChanged() {
        guard isEnabled else { return }
        playImpact(style: .rigid)
    }
    
    /// Doppia vibrazione per il blocco immagine
    func freezeActivated() {
        guard isEnabled else { return }
        playImpact(style: .medium)
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            playImpact(style: .heavy)
        }
    }
    
    /// Feedback singolo sblocco
    func freezeDeactivated() {
        guard isEnabled else { return }
        playImpact(style: .light)
    }
    
    /// Feedback Successo
    func success() {
        guard isEnabled else { return }
        playNotification(type: .success)
    }
    
    /// Feedback Errore
    func error() {
        guard isEnabled else { return }
        playNotification(type: .error)
    }
    
    // MARK: - Private Helpers
    
    private func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    private func playNotification(type: UINotificationFeedbackGenerator.FeedbackType) {
        if notificationGenerator == nil {
            notificationGenerator = UINotificationFeedbackGenerator()
        }
        notificationGenerator?.prepare()
        notificationGenerator?.notificationOccurred(type)
    }
}
