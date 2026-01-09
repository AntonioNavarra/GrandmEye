//
//  FreezeView.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 25/11/25.
//

import SwiftUI

struct FreezeView: View {
    let image: UIImage
    @Binding var zoomFactor: CGFloat
    var onUnfreeze: () -> Void
    var onSave: () -> Void
    
    @State private var currentOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomFactor)
                    .offset(x: currentOffset.width + dragOffset.width,
                            y: currentOffset.height + dragOffset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in if zoomFactor > 1.0 { dragOffset = value.translation } }
                            .onEnded { value in
                                if zoomFactor > 1.0 {
                                    let newOffset = CGSize(width: currentOffset.width + value.translation.width, height: currentOffset.height + value.translation.height)
                                    withAnimation(.spring()) {
                                        currentOffset = clampOffset(newOffset, viewSize: geometry.size)
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                
                // Badge Stato Localizzato
                VStack {
                    HStack {
                        Text(Localization.frozenStatus) // Localizzato (FERMO / FROZEN)
                            .font(.system(size: 14, weight: .black))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                            .shadow(radius: 4)
                        
                        Spacer()
                    }
                    .padding(.top, 50)
                    .padding(.horizontal)
                    Spacer()
                }
            }
        }
    }
    
    private func clampOffset(_ offset: CGSize, viewSize: CGSize) -> CGSize {
        let scaledWidth = viewSize.width * zoomFactor
        let scaledHeight = viewSize.height * zoomFactor
        let maxX = (scaledWidth - viewSize.width) / 2
        let maxY = (scaledHeight - viewSize.height) / 2
        return CGSize(width: min(max(offset.width, -maxX), maxX), height: min(max(offset.height, -maxY), maxY))
    }
}
