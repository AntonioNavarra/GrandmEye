import SwiftUI

/// Zoom controls using native String Catalog keys for accessibility.
struct ZoomControls: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    
    var body: some View {
        HStack(spacing: 30) {
            Button(action: decreaseZoom) {
                Image(systemName: "minus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(canDecrease ? Color("TextPrimary") : Color.gray)
                    .frame(width: 60, height: 60)
                    .background(Color("ButtonBackground"))
                    .clipShape(Circle())
            }
            .disabled(!canDecrease)
            // Using LocalizedStringKey automatically
            .accessibilityLabel("ally_zoom_out")
            
            Text(String(format: "%.1fx", value))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color("AccentColor"))
                .frame(width: 100)
                .contentTransition(.numericText(value: Double(value)))
                .accessibilityLabel("\(String(localized: "ui_read")) \(String(format: "%.1f", value))")
            
            Button(action: increaseZoom) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(canIncrease ? Color("TextPrimary") : Color.gray)
                    .frame(width: 60, height: 60)
                    .background(Color("ButtonBackground"))
                    .clipShape(Circle())
            }
            .disabled(!canIncrease)
            .accessibilityLabel("ally_zoom_in")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color("BackgroundSecondary").opacity(0.8))
        )
    }
    
    var canIncrease: Bool { value < range.upperBound }
    var canDecrease: Bool { value > range.lowerBound }
    
    private func increaseZoom() {
        let newValue = min(value + 0.5, range.upperBound)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { value = newValue }
        HapticManager.shared.buttonTap()
        AudioManager.shared.playZoomTick()
    }
    
    private func decreaseZoom() {
        let newValue = max(value - 0.5, range.lowerBound)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { value = newValue }
        HapticManager.shared.buttonTap()
        AudioManager.shared.playZoomTick()
    }
}
