import Vision
import AVFoundation
import UIKit

/// Text found in an image plus how sure Vision is about it (0...1).
struct OCRResult {
    let text: String
    let confidence: Float
}

/// Manages Text Recognition (OCR) and Text-to-Speech (TTS) with language awareness.
@MainActor
final class OCRManager: NSObject, AVSpeechSynthesizerDelegate {
    
    static let shared = OCRManager()
    private let synthesizer = AVSpeechSynthesizer()
    var onSpeechDidFinish: (() -> Void)?
    /// Called with the range (in the full text) of the word being spoken.
    var onWillSpeakWord: ((NSRange) -> Void)?
    /// Fixed, slightly slow speech rate for clarity.
    let rate: Float = 0.42
    /// Where (in the full text) each queued utterance starts, to map the spoken word back.
    private var utteranceOffsets: [ObjectIdentifier: Int] = [:]
    
    override private init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - OCR
    
    /// Recognizes text in an image, prioritizing the selected language.
    func recognizeText(in image: UIImage, languageCode: String) async -> OCRResult? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                let pairs = observations.compactMap { obs in
                    obs.topCandidates(1).first.map { (candidate: $0, box: obs.boundingBox) }
                }
                let candidates = pairs.map(\.candidate)
                // Rebuild paragraphs, lists and headings from the position of each line.
                let text = TextStructurer.structure(pairs.map { RecognizedLine(text: $0.candidate.string, box: $0.box) })
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                // Confidence weighted by text length, so tiny noisy fragments weigh little.
                let totalChars = candidates.reduce(0) { $0 + $1.string.count }
                let weighted = candidates.reduce(Float(0)) { $0 + $1.confidence * Float($1.string.count) }
                continuation.resume(returning: OCRResult(text: text, confidence: totalChars > 0 ? weighted / Float(totalChars) : 0))
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
    
    func normalizeText(_ text: String, languageCode: String) -> String {
        var result = text
        result = normalizeDates(in: result, languageCode: languageCode)
        result = normalizeCurrency(in: result, languageCode: languageCode)
        // Collapse runs of spaces but keep paragraph and list structure.
        result = result.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: " ?\\n ?", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - TTS (Speech)
    
    /// Speaks text using the specific voice accent corresponding to the language code.
    func speak(_ text: String, languageCode: String, startingAt offset: Int = 0) {
        stop()
        
        let ns = text as NSString
        let safeOffset = min(max(0, offset), ns.length)
        
        // Map language code (e.g., "it") to a full BCP-47 tag for the voice (e.g., "it-IT")
        let langTag = languageCode.lowercased() == "it" ? "it-IT" : "en-US"
        let voice = AVSpeechSynthesisVoice(language: langTag)
            ?? AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.lowercased().hasPrefix(languageCode.lowercased()) })
        
        do {
            let session = AVAudioSession.sharedInstance()
            // Set category for playback and duck other audio (like music)
            try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try session.setActive(true)
        } catch {
            // Still try to speak: an audio session that refuses to activate must not leave the user in silence.
            print("OCRManager TTS Error: \(error.localizedDescription)")
        }
        
        // One utterance per paragraph: a short silence between them, like a person reading.
        var cursor = safeOffset
        for paragraph in ns.substring(from: safeOffset).components(separatedBy: "\n\n") {
            let length = (paragraph as NSString).length
            defer { cursor += length + 2 }
            guard !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            
            let utterance = AVSpeechUtterance(string: paragraph)
            utterance.voice = voice
            utterance.rate = rate
            utterance.pitchMultiplier = 1.0
            utterance.volume = 1.0
            utterance.postUtteranceDelay = 0.6
            utteranceOffsets[ObjectIdentifier(utterance)] = cursor
            synthesizer.speak(utterance)
        }
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        utteranceOffsets.removeAll()
    }
    
    func pause() { synthesizer.pauseSpeaking(at: .word) }
    func resume() { synthesizer.continueSpeaking() }
    
    /// Output volume of the phone (0...1).
    var outputVolume: Float { AVAudioSession.sharedInstance().outputVolume }
    
    // MARK: - Internal Normalization Logic
    
    private func normalizeDates(in text: String, languageCode: String) -> String {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return text }
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = detector.matches(in: text, options: [], range: range)
        var processed = text
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        // Use the app-selected language, not the device locale, so text and voice match.
        formatter.locale = Locale(identifier: languageCode)
        
        for match in matches.reversed() {
            if let date = match.date, let range = Range(match.range, in: processed) {
                processed.replaceSubrange(range, with: formatter.string(from: date))
            }
        }
        return processed
    }
    
    private func normalizeCurrency(in text: String, languageCode: String) -> String {
        let pattern = #"(?:€|EUR)\s?(\d+)(?:[.,](\d{1,2}))?|(\d+)(?:[.,](\d{1,2}))?\s?(?:€|EUR)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return text }
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        var processed = text
        let euroWord = String.localized("ocr_euro", languageCode: languageCode)
        let andWord = String.localized("ocr_and", languageCode: languageCode)
        let centsWord = String.localized("ocr_cents", languageCode: languageCode)
        
        for match in matches.reversed() {
            let intPart = (match.range(at: 1).location != NSNotFound) ? (text as NSString).substring(with: match.range(at: 1)) : (match.range(at: 3).location != NSNotFound ? (text as NSString).substring(with: match.range(at: 3)) : "0")
            let decPart = (match.range(at: 2).location != NSNotFound) ? (text as NSString).substring(with: match.range(at: 2)) : (match.range(at: 4).location != NSNotFound ? (text as NSString).substring(with: match.range(at: 4)) : nil)
            
            var spoken = "\(intPart) \(euroWord)"
            if let cents = decPart, !cents.isEmpty, cents != "00" {
                spoken += " \(andWord) \(cents) \(centsWord)"
            }
            if let range = Range(match.range, in: processed) {
                processed.replaceSubrange(range, with: spoken)
            }
        }
        return processed
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let key = ObjectIdentifier(utterance)
        Task { @MainActor in
            let base = self.utteranceOffsets[key] ?? 0
            self.onWillSpeakWord?(NSRange(location: characterRange.location + base, length: characterRange.length))
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.onSpeechDidFinish?() }
    }
}
