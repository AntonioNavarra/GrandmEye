//
//  LenteFacileApp.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 24/11/25.
//

import SwiftUI

@main
struct LenteSempliceApp: App {
    
    // Inizializza le impostazioni all'avvio per assicurarsi che i manager siano configurati
    init() {
        let settings = AppSettings.load()
        // Configura i singleton MainActor
        Task { @MainActor in
            AudioManager.shared.configure(enabled: settings.soundEnabled, volume: settings.soundVolume)
            HapticManager.shared.setEnabled(settings.hapticEnabled)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            // La schermata principale è la CameraView
            CameraView()
                // Forza il tema scuro per l'intera app come da requisiti
                .preferredColorScheme(.dark)
                // Assicura che i testi grandi (Dynamic Type) non rompano il layout critico,
                // ma manteniamo il supporto dove possibile.
                // Per un'app MVP per anziani con UI custom grande, a volte si limita lo scaling automatico
                // se i controlli sono già disegnati molto grandi.
                // Qui lasciamo lo standard per accessibilità.
        }
    }
}
