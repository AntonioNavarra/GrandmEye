import SwiftUI

/// Button-based zoom controls for better accessibility.
struct ZoomControls: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    
    var body: some View {
        HStack(spacing: 20) {
            // DECREASE BUTTON
            Button(action: decreaseZoom) {
                Image(systemName: "minus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(value > range.lowerBound ? Color("TextPrimary") : .gray)
                    .frame(width: 56, height: 56)
                    .background(Color("ButtonBackground"))
                    .clipShape(Circle())
            }
            .disabled(value <= range.lowerBound)
            .accessibilityLabel("Decrease zoom")
            
            // VALUE DISPLAY
            Text(String(format: "%.1fx", value))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color("AccentColor"))
                .frame(width: 100)
                .contentTransition(.numericText(value: Double(value)))
            
            // INCREASE BUTTON
            Button(action: increaseZoom) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(value < range.upperBound ? Color("TextPrimary") : .gray)
                    .frame(width: 56, height: 56)
                    .background(Color("ButtonBackground"))
                    .clipShape(Circle())
            }
            .disabled(value >= range.upperBound)
            .accessibilityLabel("Increase zoom")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 35)
                .fill(Color("BackgroundSecondary").opacity(0.8))
        )
    }
    
    private func increaseZoom() {
        let newValue = min(value + 0.5, range.upperBound)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            value = newValue
        }
        triggerTick()
    }
    
    private func decreaseZoom() {
        let newValue = max(value - 0.5, range.lowerBound)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            value = newValue
        }
        triggerTick()
    }
    
    private func triggerTick() {
        HapticManager.shared.buttonTap()
        AudioManager.shared.playZoomTick()
    }
}
