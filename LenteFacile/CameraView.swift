//
//  CameraView.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 24/11/25.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    // MARK: - Dependencies
    @StateObject private var viewModel = CameraViewModel()
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 1. Layer Camera / Immagine
            if viewModel.isFrozen, let image = viewModel.frozenImage {
                // Immagine Statica (Freeze)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
                    .overlay(alignment: .topLeading) {
                        freezeBadge
                    }
            } else {
                // Live Camera
                // Passiamo la sessione opzionale. Se nil, mostrerà nero finché non è pronta.
                if let session = viewModel.session {
                    CameraPreview(session: session)
                        .ignoresSafeArea()
                        .opacity(viewModel.permissionGranted ? 1 : 0)
                } else {
                    // Loading placeholder
                    Color.black.ignoresSafeArea()
                }
            }
            
            // 2. Layer Controlli
            controlsLayer
        }
        .statusBar(hidden: true)
    }
    
    // MARK: - Subviews
    
    var controlsLayer: some View {
        VStack {
            HStack {
                Spacer()
                // Qui andrà il bottone Settings in Fase 4
            }
            .padding()
            
            Spacer()
            
            VStack(spacing: 30) {
                ZoomSlider(
                    value: $viewModel.zoomFactor,
                    range: 1.0...10.0
                )
                .padding(.horizontal, 24)
                .disabled(viewModel.isFrozen)
                
                HStack(alignment: .center, spacing: 40) {
                    // Bottone Freeze
                    CircleButton(
                        icon: viewModel.isFrozen ? "arrow.counterclockwise" : "snowflake",
                        size: 64,
                        bgColor: Color("ButtonBackground"),
                        fgColor: .white
                    ) {
                        viewModel.toggleFreeze()
                    }
                    
                    // Bottone Azione Principale (Camera o Salva)
                    if !viewModel.isFrozen {
                        CircleButton(
                            icon: "camera.fill",
                            size: 80,
                            bgColor: Color("ButtonBackgroundPrimary"),
                            fgColor: .black
                        ) {
                            HapticManager.shared.primaryButtonTap()
                            AudioManager.shared.playCaptureSound()
                            // Logica salvataggio in arrivo...
                        }
                    } else {
                        CircleButton(
                            icon: "square.and.arrow.down",
                            size: 80,
                            bgColor: Color("ButtonBackgroundPrimary"),
                            fgColor: .black
                        ) {
                            HapticManager.shared.success()
                            // Logica salvataggio in arrivo...
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .background(
                LinearGradient(
                    colors: [.black.opacity(0.8), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 300)
                .ignoresSafeArea()
            )
        }
    }
    
    var freezeBadge: some View {
        Text("FROZEN")
            .font(.caption)
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow)
            .foregroundColor(.black)
            .cornerRadius(4)
            .padding(20)
    }
}

// MARK: - Camera Preview (UIViewRepresentable)
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        
        // FIX iOS 17: Uso di videoRotationAngle (90° per Portrait)
        if #available(iOS 17.0, *) {
            view.videoPreviewLayer.connection?.videoRotationAngle = 90
        } else {
            view.videoPreviewLayer.connection?.videoOrientation = .portrait
        }
        
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        // Aggiorniamo la sessione solo se cambia
        if uiView.videoPreviewLayer.session != session {
            uiView.videoPreviewLayer.session = session
        }
    }
    
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
}
