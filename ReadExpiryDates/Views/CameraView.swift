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
    
    // Carichiamo le impostazioni (per eventuale modalità notte)
    @State private var appSettings = AppSettings.load()
    
    // MARK: - State Locali
    @State private var freezeZoomFactor: CGFloat = 1.0
    @State private var showSettingsSheet = false
    
    // Stato per la selezione dell'area di lettura (Crop)
    @State private var isSelectingReadingArea: Bool = false
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 1. Layer Contenuto (Camera o Freeze)
            Group {
                if viewModel.isFrozen, let image = viewModel.frozenImage {
                    // MODALITÀ FREEZE (Immagine statica)
                    FreezeView(
                        image: image,
                        zoomFactor: $freezeZoomFactor,
                        onUnfreeze: { viewModel.toggleFreeze() },
                        onSave: { savePhoto() }
                    )
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    .onAppear { freezeZoomFactor = 1.0 }
                } else {
                    // MODALITÀ LIVE (Fotocamera)
                    if let session = viewModel.session {
                        CameraPreview(session: session)
                            .ignoresSafeArea()
                            .opacity(viewModel.permissionGranted ? 1 : 0)
                    } else {
                        Color.black.ignoresSafeArea()
                    }
                }
            }
            // FILTRO: Luce Rossa (Night Mode) - Applicato se attivo nelle impostazioni
            .overlay(
                Rectangle()
                    .fill(Color(red: 1.0, green: 0.0, blue: 0.0))
                    .blendMode(.multiply)
                    .opacity((appSettings.nightModeEnabled && viewModel.isFrozen) ? 1 : 0)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            )
            
            // 2. Layer Selezione Area Lettura (Overlay modale per ritaglio)
            if isSelectingReadingArea, let image = viewModel.frozenImage {
                TextSelectionView(image: image) { croppedImage in
                    // Conferma selezione: avvia OCR sull'area ritagliata
                    isSelectingReadingArea = false
                    viewModel.startReading(croppedImage: croppedImage)
                } onCancel: {
                    // Annulla selezione
                    isSelectingReadingArea = false
                }
                .transition(.opacity)
                .zIndex(100) // Assicura che sia sopra l'immagine base
            }
            
            // 3. Layer Controlli (UI Standard - Nascosto durante selezione o lettura)
            if !isSelectingReadingArea && !viewModel.isReading {
                controlsLayer
            }
            
            // 4. Layer Trascrizione (Il Foglietto con il testo letto)
            // Appare quando l'app sta leggendo E c'è del testo scansionato disponibile
            if viewModel.isReading && !viewModel.scannedText.isEmpty {
                TranscriptionView(
                    text: viewModel.scannedText,
                    onClose: {
                        viewModel.stopReading()
                    }
                )
                .zIndex(200) // Sopra a tutto
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 5. Spinner di caricamento OCR (Analisi in corso)
            if viewModel.isProcessingOCR {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("ButtonBackgroundPrimary")))
                            .scaleEffect(2)
                        Text(Localization.readingInProgress)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .zIndex(300)
            }
        }
        .statusBar(hidden: true)
        // Ricarica le impostazioni quando si torna dalla sheet o appare la view
        .onChange(of: showSettingsSheet) { _, isShowing in
            if !isShowing { appSettings = AppSettings.load() }
        }
        .onAppear { appSettings = AppSettings.load() }
    }
    
    // MARK: - Subviews (Controlli)
    
    var controlsLayer: some View {
        VStack {
            // HEADER
            HStack {
                Spacer()
                
                // Pulsante SALVA (Visibile solo in Freeze)
                if viewModel.isFrozen {
                    Button(action: { savePhoto() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down.fill")
                            Text(Localization.save)
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Color("ButtonBackgroundPrimary"))
                        .cornerRadius(20)
                    }
                    .padding(.trailing, 8)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel(Localization.save)
                }
                
                // Pulsante IMPOSTAZIONI (Visibile solo in Live)
                if !viewModel.isFrozen {
                    Button(action: { showSettings() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .transition(.opacity)
                    .accessibilityLabel(Localization.settings)
                }
            }
            .padding()
            
            Spacer()
            
            // FOOTER (Controlli Inferiori)
            VStack(spacing: 30) {
                
                // ZOOM CONTROLS (Solo Live)
                if !viewModel.isFrozen {
                    ZoomControls(
                        value: $viewModel.zoomFactor,
                        range: 1.0...10.0
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                // BARRA PULSANTI PRINCIPALE
                HStack(alignment: .center, spacing: 20) {
                    
                    // 1. SINISTRA (Vuoto per bilanciamento)
                    Color.clear.frame(width: 72, height: 72)
                    
                    Spacer()
                    
                    // 2. CENTRO
                    if !viewModel.isFrozen {
                        // LIVE: SCATTO
                        CircleButton(
                            icon: "camera.circle",
                            size: 96,
                            bgColor: Color("ButtonBackgroundPrimary"),
                            fgColor: .black
                        ) {
                            viewModel.toggleFreeze()
                        }
                        .accessibilityLabel(Localization.freeze)
                    } else {
                        // FREEZE: LEGGI
                        VStack(spacing: 8) {
                            CircleButton(
                                icon: "text.bubble.fill",
                                size: 96,
                                bgColor: Color("ButtonBackgroundPrimary"),
                                fgColor: .black
                            ) {
                                // Avvia la selezione dell'area di lettura
                                withAnimation { isSelectingReadingArea = true }
                            }
                            .accessibilityLabel(Localization.read)
                            
                            // Etichetta esplicita
                            Text(Localization.read)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Color("AccentColor"))
                                .shadow(color: .black, radius: 2)
                        }
                    }
                    
                    Spacer()
                    
                    // 3. DESTRA
                    if !viewModel.isFrozen {
                        // LIVE: TORCIA
                        CircleButton(
                            icon: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                            size: 72,
                            // Giallo se accesa, Grigio scuro se spenta
                            bgColor: viewModel.isTorchOn ? Color("ButtonBackgroundPrimary") : Color("ButtonBackground"),
                            fgColor: viewModel.isTorchOn ? .black : .white
                        ) {
                            viewModel.toggleTorch()
                        }
                        .accessibilityLabel(viewModel.isTorchOn ? Localization.torchOn : Localization.torchOff)
                    } else {
                        // FREEZE: INDIETRO (Sblocca)
                        CircleButton(
                            icon: "arrow.counterclockwise",
                            size: 72,
                            bgColor: Color("ButtonBackground"),
                            fgColor: .white
                        ) {
                            viewModel.toggleFreeze()
                        }
                        .accessibilityLabel(Localization.back)
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 30)
            }
            .background(
                LinearGradient(colors: [.black.opacity(0.9), .black.opacity(0.0)], startPoint: .bottom, endPoint: .top)
                    .frame(height: 360).ignoresSafeArea()
            )
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
    }
    
    // MARK: - Actions
    
    private func showSettings() {
        HapticManager.shared.buttonTap()
        showSettingsSheet = true
    }
    
    private func savePhoto() {
        guard let image = viewModel.frozenImage else { return }
        PhotoManager.shared.saveImage(image) { success, error in
            if success {
                HapticManager.shared.success()
                AudioManager.shared.playSaveSuccess()
            } else {
                HapticManager.shared.error()
                AudioManager.shared.playError()
            }
        }
    }
}

// MARK: - Text Selection View (Gestione Ritaglio)

struct TextSelectionView: View {
    let image: UIImage
    var onConfirm: (UIImage) -> Void
    var onCancel: () -> Void
    
    // Stato del rettangolo di selezione (normalizzato 0...1)
    @State private var selectionRect: CGRect = CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.3)
    @State private var showHandHint: Bool = true
    @State private var animateHand: Bool = false
    @State private var userHasInteracted: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let rect = rectFromNormalized(selectionRect, in: size)
            
            ZStack {
                // Sfondo semitrasparente
                Color.black.opacity(0.8).ignoresSafeArea()
                
                // Immagine
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay(
                        SelectionOverlayShape(selectionRect: rect)
                            .fill(Color.black.opacity(0.6))
                    )
                
                // Riquadro di Selezione Interattivo
                ZStack {
                    Rectangle()
                        .stroke(Color("AccentColor"), lineWidth: 4)
                        .background(Color.white.opacity(0.01))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    userHasInteracted = true
                                    moveRect(value: value, size: size)
                                }
                        )
                    
                    // Maniglie agli angoli
                    ResizeHandle(at: CGPoint(x: rect.minX, y: rect.minY)).gesture(DragGesture().onChanged { v in userHasInteracted = true; updateRect(corner: .topLeft, location: v.location, size: size) })
                    ResizeHandle(at: CGPoint(x: rect.maxX, y: rect.minY)).gesture(DragGesture().onChanged { v in userHasInteracted = true; updateRect(corner: .topRight, location: v.location, size: size) })
                    ResizeHandle(at: CGPoint(x: rect.minX, y: rect.maxY)).gesture(DragGesture().onChanged { v in userHasInteracted = true; updateRect(corner: .bottomLeft, location: v.location, size: size) })
                    ResizeHandle(at: CGPoint(x: rect.maxX, y: rect.maxY)).gesture(DragGesture().onChanged { v in userHasInteracted = true; updateRect(corner: .bottomRight, location: v.location, size: size) })
                    
                    // Mano Guida Animata
                    if !userHasInteracted {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 4, x: 2, y: 2)
                            .position(x: rect.maxX, y: rect.maxY)
                            .offset(x: animateHand ? -40 : 20, y: animateHand ? -40 : 20)
                            .opacity(animateHand ? 0.0 : 1.0)
                            .allowsHitTesting(false)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: false)) {
                                    animateHand = true
                                }
                            }
                    }
                }
                
                // Istruzioni e Pulsanti Conferma
                VStack {
                    Text(Localization.frameText)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(.top, 60)
                    
                    Spacer()
                    
                    HStack(spacing: 30) {
                        Button(action: onCancel) {
                            Text(Localization.cancel)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(height: 50)
                                .padding(.horizontal, 30)
                                .background(Color.gray)
                                .cornerRadius(25)
                        }
                        
                        Button(action: {
                            let crop = cropImage(image, normalizedRect: selectionRect, viewSize: size)
                            onConfirm(crop)
                        }) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(Localization.read)
                            }
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .frame(height: 50)
                            .padding(.horizontal, 30)
                            .background(Color("AccentColor"))
                            .cornerRadius(25)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
    }
    
    // Logica di selezione
    enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
    
    func moveRect(value: DragGesture.Value, size: CGSize) {
        let currentW = selectionRect.width; let currentH = selectionRect.height
        let newX = value.location.x / size.width - currentW/2; let newY = value.location.y / size.height - currentH/2
        let clampedX = max(0, min(1 - currentW, newX)); let clampedY = max(0, min(1 - currentH, newY))
        selectionRect.origin = CGPoint(x: clampedX, y: clampedY)
    }
    
    func updateRect(corner: Corner, location: CGPoint, size: CGSize) {
        let nLoc = CGPoint(x: location.x / size.width, y: location.y / size.height); var r = selectionRect; let minS: CGFloat = 0.05
        switch corner {
        case .topLeft: let maxX = r.maxX - minS; let maxY = r.maxY - minS; let newX = min(maxX, max(0, nLoc.x)); let newY = min(maxY, max(0, nLoc.y)); r = CGRect(x: newX, y: newY, width: r.maxX - newX, height: r.maxY - newY)
        case .topRight: let minX = r.minX + minS; let maxY = r.maxY - minS; let newMaxX = max(minX, min(1, nLoc.x)); let newY = min(maxY, max(0, nLoc.y)); r = CGRect(x: r.minX, y: newY, width: newMaxX - r.minX, height: r.maxY - newY)
        case .bottomLeft: let maxX = r.maxX - minS; let minY = r.minY + minS; let newX = min(maxX, max(0, nLoc.x)); let newMaxY = max(minY, min(1, nLoc.y)); r = CGRect(x: newX, y: r.minY, width: r.maxX - newX, height: newMaxY - r.minY)
        case .bottomRight: let minX = r.minX + minS; let minY = r.minY + minS; let newMaxX = max(minX, min(1, nLoc.x)); let newMaxY = max(minY, min(1, nLoc.y)); r = CGRect(x: r.minX, y: r.minY, width: newMaxX - r.minX, height: newMaxY - r.minY)
        }
        selectionRect = r
    }
    
    func rectFromNormalized(_ norm: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: norm.minX * size.width, y: norm.minY * size.height, width: norm.width * size.width, height: norm.height * size.height)
    }
    
    func cropImage(_ original: UIImage, normalizedRect: CGRect, viewSize: CGSize) -> UIImage {
        let imageRatio = original.size.width / original.size.height; let viewRatio = viewSize.width / viewSize.height
        var renderRect = CGRect.zero
        if imageRatio > viewRatio {
            let scale = viewSize.width / original.size.width; let height = original.size.height * scale
            renderRect = CGRect(x: 0, y: (viewSize.height - height) / 2, width: viewSize.width, height: height)
        } else {
            let scale = viewSize.height / original.size.height; let width = original.size.width * scale
            renderRect = CGRect(x: (viewSize.width - width) / 2, y: 0, width: width, height: viewSize.height)
        }
        let selectionInView = rectFromNormalized(normalizedRect, in: viewSize); let intersection = selectionInView.intersection(renderRect)
        let scaleX = original.size.width / renderRect.width; let scaleY = original.size.height / renderRect.height
        let cropRect = CGRect(x: (intersection.minX - renderRect.minX) * scaleX, y: (intersection.minY - renderRect.minY) * scaleY, width: intersection.width * scaleX, height: intersection.height * scaleY)
        if let cgImage = original.cgImage?.cropping(to: cropRect) { return UIImage(cgImage: cgImage, scale: original.scale, orientation: original.imageOrientation) }
        return original
    }
}

// MARK: - Helpers Grafici

struct ResizeHandle: View {
    let at: CGPoint
    var body: some View { Circle().fill(Color.white).frame(width: 32, height: 32).shadow(radius: 2).position(at) }
}

struct SelectionOverlayShape: Shape {
    var selectionRect: CGRect
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRect(selectionRect)
        return path
    }
}

// MARK: - Camera Preview (AVFoundation)

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if #available(iOS 17.0, *) {
            view.videoPreviewLayer.connection?.videoRotationAngle = 90
        } else {
            view.videoPreviewLayer.connection?.videoOrientation = .portrait
        }
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        if uiView.videoPreviewLayer.session != session {
            uiView.videoPreviewLayer.session = session
        }
    }
    
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
