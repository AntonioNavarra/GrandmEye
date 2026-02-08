import Vision
import AVFoundation
import UIKit

/// Manages Text Recognition (OCR) and Text-to-Speech (TTS) with language awareness.
@MainActor
final class OCRManager: NSObject, AVSpeechSynthesizerDelegate {
    
    static let shared = OCRManager()
    private let synthesizer = AVSpeechSynthesizer()
    var onSpeechDidFinish: (() -> Void)?
    
    override private init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - OCR
    
    /// Recognizes text in an image, prioritizing the selected language.
    func recognizeText(in image: UIImage, languageCode: String) async -> String? {
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
            // Prioritize the language selected in settings, fallback to English
            request.recognitionLanguages = [languageCode, "en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    // MARK: - Normalization
    
    func normalizeText(_ text: String) -> String {
        var result = text
        result = normalizeDates(in: result)
        result = normalizeCurrency(in: result)
        return result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
    
    // MARK: - TTS (Speech)
    
    /// Speaks text using the specific voice accent corresponding to the language code.
    func speak(_ text: String, languageCode: String) {
        stop()
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Map language code (e.g., "it") to a full BCP-47 tag for the voice (e.g., "it-IT")
        let langTag = languageCode.lowercased() == "it" ? "it-IT" : "en-US"
        
        // Explicitly set the voice using the language tag to ensure the correct accent
        if let voice = AVSpeechSynthesisVoice(language: langTag) {
            utterance.voice = voice
        } else {
            // Fallback: search for any available voice that matches the language code prefix
            let voices = AVSpeechSynthesisVoice.speechVoices()
            utterance.voice = voices.first(where: { $0.language.lowercased().hasPrefix(languageCode.lowercased()) })
        }
        
        // Adjusted rate for better clarity for seniors
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        do {
            let session = AVAudioSession.sharedInstance()
            // Set category for playback and duck other audio (like music)
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
            synthesizer.speak(utterance)
        } catch {
            print("OCRManager TTS Error: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
    
    // MARK: - Internal Normalization Logic
    
    private func normalizeDates(in text: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return text }
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = detector.matches(in: text, options: [], range: range)
        var processed = text
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        
        for match in matches.reversed() {
            if let date = match.date, let range = Range(match.range, in: processed) {
                processed.replaceSubrange(range, with: formatter.string(from: date))
            }
        }
        return processed
    }
    
    private func normalizeCurrency(in text: String) -> String {
        let pattern = #"(?:€|EUR)\s?(\d+)(?:[.,](\d{1,2}))?|(\d+)(?:[.,](\d{1,2}))?\s?(?:€|EUR)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        var processed = text
        
        for match in matches.reversed() {
            let intPart = (match.range(at: 1).location != NSNotFound) ? (text as NSString).substring(with: match.range(at: 1)) : (match.range(at: 3).location != NSNotFound ? (text as NSString).substring(with: match.range(at: 3)) : "0")
            let decPart = (match.range(at: 2).location != NSNotFound) ? (text as NSString).substring(with: match.range(at: 2)) : (match.range(at: 4).location != NSNotFound ? (text as NSString).substring(with: match.range(at: 4)) : nil)
            
            var spoken = "\(intPart) euro"
            if let cents = decPart, !cents.isEmpty, cents != "00" {
                spoken += " and \(cents) cents"
            }
            if let range = Range(match.range, in: processed) {
                processed.replaceSubrange(range, with: spoken)
            }
        }
        return processed
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.onSpeechDidFinish?() }
    }
}
