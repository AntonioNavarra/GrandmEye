import AVFoundation

/// Manages UI sound feedback.
@MainActor
final class AudioManager {
    static let shared = AudioManager()
    private var isEnabled: Bool = true
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio Manager Error: \(error)")
        }
    }
    
    func configure(enabled: Bool, volume: Float) {
        self.isEnabled = enabled
    }
    
    func playButtonTap() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1104)
    }
    
    func playFreezeSound() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1100)
    }
    
    func playUnfreezeSound() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1101)
    }
    
    func playZoomTick() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1157)
    }
    
    func playSaveSuccess() {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(1001)
    }
}
