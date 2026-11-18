import SwiftUI

/// Wide, high-contrast primary button (e.g. "LEGGI").
struct BigActionButton: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    var height: CGFloat = 120
    var style: Style = .primary
    let action: () -> Void

    enum Style { case primary, light, dark }

    var body: some View {
        Button {
            HapticManager.shared.buttonTap()
            AudioManager.shared.playButtonTap()
            action()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: height * 0.38, weight: .bold))
                Text(titleKey)
                    .font(.system(size: height * 0.36, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: height / 3))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var foreground: Color {
        switch style {
        case .primary, .light: return .black
        case .dark: return .white
        }
    }
    private var background: Color {
        switch style {
        case .primary: return Color("ButtonBackgroundPrimary")
        case .light: return .white
        case .dark: return Color("ButtonBackground")
        }
    }
}

/// Circle button with a large text label underneath.
struct LabeledCircleButton: View {
    let systemImage: String
    let labelKey: LocalizedStringKey
    var size: CGFloat = 88
    var isPrimary = false
    var showLabel = true
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.buttonTap()
            AudioManager.shared.playButtonTap()
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundColor(isPrimary ? .black : .white)
                    .frame(width: size, height: size)
                    .background(isPrimary ? Color("ButtonBackgroundPrimary") : Color("ButtonBackground"))
                    .clipShape(Circle())
                if showLabel {
                    Text(labelKey)
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                        .foregroundColor(isPrimary ? Color("ButtonBackgroundPrimary") : .white)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 100)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel(labelKey)
    }
}

/// Small bordered pill (e.g. "Opzioni").
struct PillButton: View {
    let titleKey: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.buttonTap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage) }
                Text(titleKey).lineLimit(1).minimumScaleFactor(0.7)
            }
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .frame(height: 56)
            .background(Color.black.opacity(0.85))
            .overlay(Capsule().stroke(Color.white, lineWidth: 2))
            .clipShape(Capsule())
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

/// Three fixed zoom steps instead of a slider.
struct ZoomPresets: View {
    @Binding var value: CGFloat
    var steps: [CGFloat] = [2, 4, 8]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(steps, id: \.self) { step in
                let selected = abs(value - step) < 0.5
                Button {
                    HapticManager.shared.buttonTap()
                    value = step
                } label: {
                    Text("\(Int(step))x")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(selected ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(selected ? Color("ButtonBackgroundPrimary") : Color("ButtonBackground"))
                        .clipShape(Capsule())
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("\(Int(step))x")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
