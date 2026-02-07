import SwiftUI

/// A view that displays transcribed text using native String Catalog keys.
struct TranscriptionView: View {
    let text: String
    var onClose: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Transcription sheet
            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.black)
                    
                    // Native key from Localizable.xcstrings
                    Text("transcription_title")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Close button
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.black.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding()
                .background(Color("AccentColor"))
                
                // Content
                ScrollView {
                    Text(text)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .lineSpacing(8)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color("BackgroundSecondary"))
                .frame(maxHeight: 400)
                
                // Footer
                HStack {
                    // Native key from Localizable.xcstrings
                    Text("ui_reading_in_progress")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    // Animated waveform icon
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative.reversing, isActive: true)
                        .foregroundColor(Color("AccentColor"))
                }
                .padding()
                .background(Color("BackgroundSecondary"))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.gray.opacity(0.2)),
                    alignment: .top
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

#Preview {
    // Note: Localized keys in previews require the correct environment or real device testing
    TranscriptionView(text: "Sample transcription text", onClose: {})
}
