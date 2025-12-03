//
//  OCRManager.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 25/11/25.
//

import Vision
import AVFoundation
import UIKit

/// Gestisce il riconoscimento del testo (OCR) e la sintesi vocale (TTS).
@MainActor
final class OCRManager: NSObject, AVSpeechSynthesizerDelegate {
    
    static let shared = OCRManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    var onSpeechDidFinish: (() -> Void)?
    
    override private init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - Public Methods
    
    func recognizeText(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                continuation.resume(returning: text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            let currentLang = Locale.current.identifier
            request.recognitionLanguages = [currentLang, "en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    /// Normalizza il testo (Date, Prezzi) per renderlo leggibile e ascoltabile.
    /// Ora è pubblico per poter mostrare il testo elaborato nella UI.
    func normalizeText(_ text: String) -> String {
        var result = text
        result = normalizeDates(in: result)
        result = normalizeCurrency(in: result)
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result
    }
    
    /// Legge il testo fornito.
    func speak(_ text: String) {
        stop()
        
        let utterance = AVSpeechUtterance(string: text)
        let currentLang = Locale.current.identifier
        utterance.voice = AVSpeechSynthesisVoice(language: currentLang)
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        synthesizer.speak(utterance)
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    var isSpeaking: Bool {
        synthesizer.isSpeaking
    }
    
    // MARK: - Private Normalization Logic
    
    private func normalizeDates(in text: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return text }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        var processedText = text
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = .long
        for match in matches.reversed() {
            if let date = match.date, let range = Range(match.range, in: processedText) {
                let spokenDate = dateFormatter.string(from: date)
                processedText.replaceSubrange(range, with: spokenDate)
            }
        }
        return processedText
    }
    
    private func normalizeCurrency(in text: String) -> String {
        let pattern = #"(?:€|EUR)\s?(\d+)(?:[.,](\d{1,2}))?|(\d+)(?:[.,](\d{1,2}))?\s?(?:€|EUR)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        var processedText = text
        for match in matches.reversed() {
            let intPart = (match.range(at: 1).location != NSNotFound) ? (text as NSString).substring(with: match.range(at: 1)) : (match.range(at: 3).location != NSNotFound ? (text as NSString).substring(with: match.range(at: 3)) : "0")
            let decPart = (match.range(at: 2).location != NSNotFound) ? (text as NSString).substring(with: match.range(at: 2)) : (match.range(at: 4).location != NSNotFound ? (text as NSString).substring(with: match.range(at: 4)) : nil)
            
            var spokenString = "\(intPart) \(Localization.currencyEuro)"
            if let cents = decPart, !cents.isEmpty, cents != "00" {
                spokenString += " \(Localization.conjunctionAnd) \(cents) \(Localization.currencyCents)"
            }
            if let range = Range(match.range, in: processedText) {
                processedText.replaceSubrange(range, with: spokenString)
            }
        }
        return processedText
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.onSpeechDidFinish?()
        }
    }
}
