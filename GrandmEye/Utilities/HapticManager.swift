import UIKit

/// Manages haptic feedback.
@MainActor
final class HapticManager {
    static let shared = HapticManager()
    private var isEnabled: Bool = true
    
    private var selectionGenerator: UISelectionFeedbackGenerator?
    
    private init() {}
    
    func setEnabled(_ enabled: Bool) {
        self.isEnabled = enabled
    }
    
    func buttonTap() {
        guard isEnabled else { return }
        playImpact(style: .light)
    }
    
    func selectionChanged() {
        guard isEnabled else { return }
        if selectionGenerator == nil {
            selectionGenerator = UISelectionFeedbackGenerator()
        }
        selectionGenerator?.prepare()
        selectionGenerator?.selectionChanged()
    }
    
    func freezeActivated() {
        guard isEnabled else { return }
        playImpact(style: .medium)
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            playImpact(style: .heavy)
        }
    }
    
    func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    func error() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    private func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}
