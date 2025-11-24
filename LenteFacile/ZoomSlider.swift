//
//  ZoomSlider.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 24/11/25.
//

import SwiftUI

/// Slider personalizzato per il controllo dello zoom con feedback visivo e aptico.
struct ZoomSlider: View {
    // MARK: - Bindings
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    
    // MARK: - State
    @State private var isDragging: Bool = false
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 12) {
            // Etichetta Valore Zoom (es. "2.5x")
            Text(String(format: "%.1fx", value))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(Color("AccentColor"))
                .shadow(color: .black.opacity(0.5), radius: 2)
                // Evita il "balletto" del layout quando cambia la larghezza del testo
                .frame(width: 120, height: 40)
                .contentTransition(.numericText(value: Double(value)))
            
            HStack(spacing: 16) {
                // Pulsante Meno
                Button(action: decreaseZoom) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(Color("TextPrimary"))
                        .frame(width: 44, height: 44)
                        .background(Color("ButtonBackground"))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Diminuisci zoom")
                
                // Slider Custom
                Slider(value: $value, in: range, step: 0.1) { editing in
                    isDragging = editing
                    if editing {
                        HapticManager.shared.selectionChanged() // Feedback inizio tocco
                    }
                }
                .accentColor(Color("AccentColor"))
                .onChange(of: value) { oldValue, newValue in
                    handleValueChange(old: oldValue, new: newValue)
                }
                
                // Pulsante Più
                Button(action: increaseZoom) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(Color("TextPrimary"))
                        .frame(width: 44, height: 44)
                        .background(Color("ButtonBackground"))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Aumenta zoom")
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("BackgroundSecondary").opacity(0.8))
        )
    }
    
    // MARK: - Logic
    
    private func increaseZoom() {
        let newValue = min(value + 1.0, range.upperBound)
        // Arrotonda al prossimo intero se siamo vicini
        let rounded = round(newValue * 10) / 10
        withAnimation(.smooth) {
            value = rounded
        }
        triggerTick()
    }
    
    private func decreaseZoom() {
        let newValue = max(value - 1.0, range.lowerBound)
        let rounded = round(newValue * 10) / 10
        withAnimation(.smooth) {
            value = rounded
        }
        triggerTick()
    }
    
    private func handleValueChange(old: CGFloat, new: CGFloat) {
        // Feedback aptico quando si attraversa un numero intero (es. 2.9 -> 3.0)
        if Int(old) != Int(new) {
            HapticManager.shared.valueChanged()
        }
        // Feedback leggero (tick) per piccoli incrementi durante il drag
        else if abs(new - old) > 0.1 && isDragging {
            // Riduciamo la frequenza per non sovraccaricare l'haptic engine
            // In un'app reale useremmo un timer o debounce, qui semplifichiamo
            if Int(new * 10) % 2 == 0 { // Tick ogni 0.2x
                HapticManager.shared.sliderTick()
            }
        }
    }
    
    private func triggerTick() {
        HapticManager.shared.sliderTap() // Metodo helper aggiunto mentalmente o usa buttonTap
        AudioManager.shared.playZoomTick()
    }
}

// Estensione veloce per supportare il metodo mancante in HapticManager se non definito prima
fileprivate extension HapticManager {
    func selectionChanged() { sliderTick() }
    func sliderTap() { buttonTap() }
}
