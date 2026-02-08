//
//  Circle Button Component .swift
//  EasyReader
//
//  Created by Antonio Navarra on 24/11/25.
//

import SwiftUI

/// Un pulsante circolare accessibile con feedback tattile e sonoro integrato.
struct CircleButton: View {
    // MARK: - Properties
    let iconName: String
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void
    
    // MARK: - Init
    init(
        icon: String,
        size: CGFloat = 64,
        bgColor: Color = Color("ButtonBackground"),
        fgColor: Color = Color("TextPrimary"),
        action: @escaping () -> Void
    ) {
        self.iconName = icon
        self.size = size
        self.backgroundColor = bgColor
        self.foregroundColor = fgColor
        self.action = action
    }
    
    // MARK: - Body
    var body: some View {
        Button(action: {
            triggerFeedback()
            action()
        }) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                Image(systemName: iconName)
                    .font(.system(size: size * 0.45, weight: .bold)) // Icona scalata proporzionalmente
                    .foregroundColor(foregroundColor)
            }
        }
        .buttonStyle(ScaleButtonStyle()) // Animazione al tocco
        .accessibilityElement(children: .combine)
        .accessibilityLabel(labelForIcon(iconName))
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Helpers
    
    private func triggerFeedback() {
        // Integra direttamente i manager creati in Fase 1
        // Nota: In un'app reale potremmo iniettarli, ma qui usiamo i Singleton per semplicità MVP
        HapticManager.shared.buttonTap()
        AudioManager.shared.playButtonTap()
    }
    
    private func labelForIcon(_ icon: String) -> String {
        switch icon {
        case "snowflake": return "Blocca immagine"
        case "camera.fill": return "Scatta foto"
        case "arrow.counterclockwise": return "Sblocca immagine"
        case "square.and.arrow.down": return "Salva nella galleria"
        case "square.and.arrow.up": return "Condividi"
        case "plus.magnifyingglass": return "Aumenta zoom"
        case "minus.magnifyingglass": return "Diminuisci zoom"
        default: return "Pulsante"
        }
    }
}

// MARK: - Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 20) {
            CircleButton(icon: "snowflake", action: {})
            CircleButton(icon: "camera.fill", size: 80, bgColor: Color("ButtonBackgroundPrimary"), fgColor: .black, action: {})
        }
    }
}
