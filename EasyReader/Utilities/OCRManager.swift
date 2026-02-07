import Vision
import AVFoundation
import UIKit

/// Manages OCR and TTS using native localization calls.
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
            request.recognitionLanguages = [Locale.current.identifier, "en-US"]
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    func normalizeText(_ text: String) -> String {
        var result = text
        result = normalizeDates(in: result)
        result = normalizeCurrency(in: result)
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result
    }
    
    func speak(_ text: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        utterance.rate = 0.5
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        synthesizer.speak(utterance)
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    // MARK: - Normalization Logic
    
    private func normalizeDates(in text: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return text }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        var processedText = text
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        for match in matches.reversed() {
            if let date = match.date, let range = Range(match.range, in: processedText) {
                processedText.replaceSubrange(range, with: dateFormatter.string(from: date))
            }
        }
        return processedText
    }
    
    private func normalizeCurrency(in text: String) -> String {
        // Note: currency keys like "ocr_euro" should be added to Localizable.xcstrings
        let pattern = #"(?:€|EUR)\s?(\d+)(?:[.,](\d{1,2}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        var processedText = text
        
        for match in matches.reversed() {
            let intPart = (text as NSString).substring(with: match.range(at: 1))
            // Using String(localized:) for logic-based strings
            var spokenString = "\(intPart) \(String(localized: "ocr_euro", defaultValue: "euro"))"
            
            if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound {
                let cents = (text as NSString).substring(with: match.range(at: 2))
                spokenString += " \(String(localized: "ocr_and", defaultValue: "e")) \(cents) \(String(localized: "ocr_cents", defaultValue: "centesimi"))"
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
