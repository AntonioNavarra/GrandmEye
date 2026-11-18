import SwiftUI

/// Full-screen reading view: big text, the spoken word highlighted, speed and pause controls.
struct TranscriptionView: View {
    let text: String
    let highlightRange: NSRange?
    let isPaused: Bool
    let isVolumeLow: Bool
    var onTogglePause: () -> Void
    var onClose: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 16) {
                if isVolumeLow {
                    Label("volume_low", systemImage: "speaker.slash.fill")
                        .font(.title2.weight(.black))
                        .foregroundColor(.black)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color("ButtonBackgroundPrimary"))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                
                ScrollView {
                    Text(highlightedText)
                        .font(.system(size: 36, weight: .semibold))
                        .lineSpacing(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                }
                
                LabeledCircleButton(
                    systemImage: isPaused ? "play.fill" : "pause.fill",
                    labelKey: isPaused ? "reading_resume" : "reading_pause",
                    size: 108, isPrimary: true, showLabel: false, action: onTogglePause
                )
                
                BigActionButton(titleKey: "settings_close", systemImage: "xmark", height: 76, style: .light, action: onClose)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }
    
    /// The text with the word being spoken highlighted.
    private var highlightedText: AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = .white
        if let ns = highlightRange,
           let range = Range(ns, in: text),
           let attrRange = Range(range, in: attributed) {
            attributed[attrRange].backgroundColor = UIColor(named: "ButtonBackgroundPrimary") ?? .yellow
            attributed[attrRange].foregroundColor = .black
        }
        return attributed
    }
}

#Preview {
    TranscriptionView(text: "Scadenza 03/2028. Una compressa dopo i pasti.", highlightRange: NSRange(location: 0, length: 9),
                      isPaused: false, isVolumeLow: true,
                      onTogglePause: {}, onClose: {})
}
