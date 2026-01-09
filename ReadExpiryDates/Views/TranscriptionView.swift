//
//  TranscriptionView.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 28/11/25.
//

import SwiftUI

/// Un "foglietto" digitale che mostra il testo trascritto.
/// La logica di traduzione e rilevamento lingua è ora delegata al ViewModel.
struct TranscriptionView: View {
    let text: String
    var onClose: () -> Void
    
    var body: some View {
        ZStack {
            // Sfondo oscurante
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Il Foglietto
            VStack(spacing: 0) {
                // Header Foglietto
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.black)
                    
                    Text(Localization.transcriptionTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // Pulsante chiusura (Unico modo per chiudere)
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.black.opacity(0.6))
                            .frame(width: 44, height: 44) // Touch target aumentato
                    }
                }
                .padding()
                .background(Color("AccentColor")) // Giallo
                
                // Corpo del Testo
                ScrollView {
                    Text(text)
                        .font(.system(size: 24, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .lineSpacing(8)
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color("BackgroundSecondary")) // Grigio Scuro
                .frame(maxHeight: 400)
                
                // Footer (Stato Lettura)
                HStack {
                    Text(Localization.readingInProgress)
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    // Waveform animata
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
    ZStack {
        Color.gray.ignoresSafeArea()
        TranscriptionView(
            text: "Hello world\n\n[TRADUZIONE]\nCiao mondo",
            onClose: {}
        )
    }
}
