//
//  Localization.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 25/11/25.
//

import Foundation

/// Gestore semplice per la localizzazione delle stringhe.
struct Localization {
    
    static var isItalian: Bool {
        Locale.current.language.languageCode?.identifier == "it" ||
        Locale.current.identifier.hasPrefix("it")
    }
    
    // MARK: - UI General
    static var save: String { isItalian ? "SALVA" : "SAVE" }
    static var read: String { isItalian ? "LEGGI" : "READ" }
    static var stop: String { isItalian ? "STOP" : "STOP" }
    static var cancel: String { isItalian ? "Annulla" : "Cancel" }
    static var frozenStatus: String { isItalian ? "FERMO" : "FROZEN" }
    static var frameText: String { isItalian ? "Inquadra il testo" : "Frame the text" }
    static var readingInProgress: String { isItalian ? "Lettura in corso..." : "Reading in progress..." }
    
    // MARK: - Settings Headers
    static var settingsTitle: String { isItalian ? "Impostazioni" : "Settings" }
    static var close: String { isItalian ? "Chiudi" : "Close" }
    
    // MARK: - Settings Sections
    static var magnificationSection: String { isItalian ? "Ingrandimento" : "Magnification" }
    static var audioSection: String { isItalian ? "Feedback Sensoriale" : "Sensory Feedback" }
    static var infoSection: String { isItalian ? "Info" : "Info" }
    
    // MARK: - Settings Items
    static var defaultZoom: String { isItalian ? "Zoom Predefinito" : "Default Zoom" }
    static var rememberZoom: String { isItalian ? "Ricorda ultimo zoom" : "Remember last zoom" }
    static var soundInterface: String { isItalian ? "Suoni interfaccia" : "Interface sounds" }
    static var hapticFeedback: String { isItalian ? "Feedback tattile" : "Haptic feedback" }
    static var resetSettings: String { isItalian ? "Ripristina impostazioni" : "Reset settings" }
    
    // MARK: - Accessibility Labels
    static var torchOn: String { isItalian ? "Spegni torcia" : "Turn torch off" }
    static var torchOff: String { isItalian ? "Accendi torcia" : "Turn torch on" }
    static var freeze: String { isItalian ? "Scatta e blocca" : "Snap and freeze" }
    static var back: String { isItalian ? "Indietro" : "Back" }
    static var zoomIn: String { isItalian ? "Aumenta ingrandimento" : "Zoom in" }
    static var zoomOut: String { isItalian ? "Riduci ingrandimento" : "Zoom out" }
    static var settings: String { isItalian ? "Impostazioni" : "Settings" }
    
    // MARK: - Smart Reader (Valuta)
    static var currencyEuro: String { isItalian ? "euro" : "euros" }
    static var currencyCents: String { isItalian ? "centesimi" : "cents" }
    static var conjunctionAnd: String { isItalian ? "e" : "and" }
    
    // MARK: - Transcription View
    static var transcriptionTitle: String { isItalian ? "Trascrizione" : "Transcription" }
    static var translate: String { isItalian ? "TRADUCI" : "TRANSLATE" }
    static var showOriginal: String { isItalian ? "ORIGINALE" : "ORIGINAL" }
    static var translationMock: String { isItalian ? "Traduzione simulata." : "Simulated translation." }
}

