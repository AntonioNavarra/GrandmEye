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
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(paragraphs, id: \.index) { paragraph in
                                Text(highlighted(paragraph))
                                    .font(.system(size: 36, weight: .semibold))
                                    .lineSpacing(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(paragraph.index)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    // Keep the paragraph being read in view.
                    .onChange(of: activeParagraph) { _, index in
                        guard let index else { return }
                        withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(index, anchor: .center) }
                    }
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
    
    private struct Paragraph {
        let index: Int
        let start: Int      // where it begins in the full text
        let text: String
        var length: Int { (text as NSString).length }
    }
    
    /// The text split at blank lines, each with its position in the full text.
    private var paragraphs: [Paragraph] {
        var result: [Paragraph] = []
        var cursor = 0
        for (index, part) in text.components(separatedBy: "\n\n").enumerated() {
            let paragraph = Paragraph(index: index, start: cursor, text: part)
            result.append(paragraph)
            cursor += paragraph.length + 2
        }
        return result
    }
    
    /// Index of the paragraph that contains the spoken word.
    private var activeParagraph: Int? {
        guard let spoken = highlightRange else { return nil }
        return paragraphs.last(where: { $0.start <= spoken.location })?.index
    }
    
    /// A paragraph with the word being spoken highlighted.
    private func highlighted(_ paragraph: Paragraph) -> AttributedString {
        var attributed = AttributedString(paragraph.text)
        attributed.foregroundColor = .white
        guard let spoken = highlightRange,
              spoken.location >= paragraph.start, spoken.location < paragraph.start + paragraph.length else { return attributed }
        let local = NSRange(location: spoken.location - paragraph.start,
                            length: min(spoken.length, paragraph.length - (spoken.location - paragraph.start)))
        if let range = Range(local, in: paragraph.text), let attrRange = Range(range, in: attributed) {
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
