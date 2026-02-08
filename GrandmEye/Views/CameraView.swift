import SwiftUI
import AVFoundation

struct CameraView: View {
    // MARK: - Dependencies
    @StateObject private var viewModel = CameraViewModel()
    @State private var appSettings = AppSettings.load()
    
    // MARK: - Local State
    @State private var freezeZoomFactor: CGFloat = 1.0
    @State private var showSettingsSheet = false
    @State private var isSelectingReadingArea: Bool = false
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 1. Content Layer (Live Camera or Frozen Image)
            Group {
                if viewModel.isFrozen, let image = viewModel.frozenImage {
                    FreezeView(
                        image: image,
                        zoomFactor: $freezeZoomFactor,
                        onUnfreeze: { unfreezeAndReset() },
                        onSave: { savePhoto() }
                    )
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                } else {
                    if let session = viewModel.session {
                        CameraPreview(session: session)
                            .ignoresSafeArea()
                            .opacity(viewModel.permissionGranted ? 1 : 0)
                    } else {
                        Color.black.ignoresSafeArea()
                    }
                }
            }
            
            // 2. Text Selection Area Layer (Scanner)
            if isSelectingReadingArea, let image = viewModel.frozenImage {
                TextSelectionView(image: image) { croppedImage in
                    isSelectingReadingArea = false
                    viewModel.startReading(croppedImage: croppedImage)
                } onCancel: {
                    isSelectingReadingArea = false
                }
                .transition(.opacity)
                .zIndex(100)
            }
            
            // 3. Main Controls Layer
            if !isSelectingReadingArea && !viewModel.isReading {
                controlsLayer
            }
            
            // 4. Transcription Sheet Layer
            if viewModel.isReading && !viewModel.scannedText.isEmpty {
                TranscriptionView(
                    text: viewModel.scannedText,
                    onClose: { viewModel.stopReading() }
                )
                .zIndex(200)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 5. OCR Processing Spinner
            if viewModel.isProcessingOCR {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("AccentColor")))
                            .scaleEffect(2)
                        Text("ui_reading_in_progress")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .zIndex(300)
            }
        }
        .statusBar(hidden: true)
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
        .onChange(of: showSettingsSheet) { _, isShowing in
            if !isShowing { appSettings = AppSettings.load() }
        }
        .onAppear { appSettings = AppSettings.load() }
    }
    
    // MARK: - Subviews
    
    var controlsLayer: some View {
        VStack {
            // HEADER
            HStack {
                Spacer()
                
                if viewModel.isFrozen {
                    Button(action: { savePhoto() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.down.fill")
                            Text("ui_save")
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                        .padding(.vertical, 10).padding(.horizontal, 16)
                        .background(Color("ButtonBackgroundPrimary"))
                        .cornerRadius(20)
                    }
                    .padding(.trailing, 8)
                    .transition(AnyTransition.scale.combined(with: .opacity))
                    .accessibilityLabel("ui_save")
                }
                
                Button(action: {
                    HapticManager.shared.buttonTap()
                    showSettingsSheet = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .transition(.opacity)
                .accessibilityLabel("ally_settings")
            }
            .padding()
            
            Spacer()
            
            // FOOTER
            VStack(spacing: 30) {
                // BUTTON BASED ZOOM CONTROLS
                if !viewModel.isFrozen {
                    ZoomControls(value: $viewModel.zoomFactor, range: 1.0...10.0)
                        .transition(AnyTransition.scale.combined(with: .opacity))
                }
                
                HStack(alignment: .center, spacing: 20) {
                    Color.clear.frame(width: 72, height: 72)
                    Spacer()
                    
                    if !viewModel.isFrozen {
                        CircleButton(
                            icon: "camera.circle",
                            size: 96,
                            bgColor: Color("ButtonBackgroundPrimary"),
                            fgColor: .black
                        ) {
                            viewModel.toggleFreeze()
                        }
                        .accessibilityLabel("ally_freeze")
                    } else {
                        VStack(spacing: 8) {
                            CircleButton(
                                icon: "text.bubble.fill",
                                size: 96,
                                bgColor: Color("ButtonBackgroundPrimary"),
                                fgColor: .black
                            ) {
                                withAnimation { isSelectingReadingArea = true }
                            }
                            .accessibilityLabel("ui_read")
                            
                            Text("ui_read")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Color("AccentColor"))
                                .shadow(color: .black, radius: 2)
                        }
                    }
                    
                    Spacer()
                    
                    if !viewModel.isFrozen {
                        CircleButton(
                            icon: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                            size: 72,
                            bgColor: viewModel.isTorchOn ? Color("ButtonBackgroundPrimary") : Color("ButtonBackground"),
                            fgColor: viewModel.isTorchOn ? .black : .white
                        ) {
                            viewModel.toggleTorch()
                        }
                        .accessibilityLabel(viewModel.isTorchOn ? "ally_torch_off" : "ally_torch_on")
                    } else {
                        CircleButton(
                            icon: "arrow.counterclockwise",
                            size: 72,
                            bgColor: Color("ButtonBackground"),
                            fgColor: .white
                        ) {
                            unfreezeAndReset()
                        }
                        .accessibilityLabel("ally_back")
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 30)
            }
            .background(
                LinearGradient(colors: [.black.opacity(0.9), .black.opacity(0.0)], startPoint: .bottom, endPoint: .top)
                    .frame(height: 360).ignoresSafeArea()
            )
        }
    }
    
    // MARK: - Actions
    
    private func unfreezeAndReset() {
        viewModel.toggleFreeze()
        freezeZoomFactor = 1.0
    }
    
    private func savePhoto() {
        guard let image = viewModel.frozenImage else { return }
        PhotoManager.shared.saveImage(image) { success, _ in
            if success {
                HapticManager.shared.success()
                AudioManager.shared.playSaveSuccess()
            }
        }
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
        
        // Handle rotation for portrait orientation
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

// MARK: - Text Selection View

struct TextSelectionView: View {
    let image: UIImage
    var onConfirm: (UIImage) -> Void
    var onCancel: () -> Void
    
    @State private var selectionRect: CGRect = CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.3)
    @State private var userHasInteracted: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let rect = rectFromNormalized(selectionRect, in: size)
            
            ZStack {
                Color.black.opacity(0.8).ignoresSafeArea()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay(
                        SelectionOverlayShape(selectionRect: rect)
                            .fill(Color.black.opacity(0.6))
                    )
                
                // Interactive Selection Frame
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
                    
                    // Resize Handles
                    ResizeHandle(at: CGPoint(x: rect.minX, y: rect.minY)).gesture(DragGesture().onChanged { v in updateRect(corner: .topLeft, location: v.location, size: size) })
                    ResizeHandle(at: CGPoint(x: rect.maxX, y: rect.minY)).gesture(DragGesture().onChanged { v in updateRect(corner: .topRight, location: v.location, size: size) })
                    ResizeHandle(at: CGPoint(x: rect.minX, y: rect.maxY)).gesture(DragGesture().onChanged { v in updateRect(corner: .bottomLeft, location: v.location, size: size) })
                    ResizeHandle(at: CGPoint(x: rect.maxX, y: rect.maxY)).gesture(DragGesture().onChanged { v in updateRect(corner: .bottomRight, location: v.location, size: size) })
                }
                
                VStack {
                    Text("ui_frame_text") // Localized key
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(.top, 60)
                    
                    Spacer()
                    
                    HStack(spacing: 30) {
                        Button(action: onCancel) {
                            Text("ui_cancel") // Localized key
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
                                Text("ui_read") // Localized key
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
    
    // MARK: - Selection Logic
    
    private enum Corner { case topLeft, topRight, bottomLeft, bottomRight }
    
    private func moveRect(value: DragGesture.Value, size: CGSize) {
        let currentW = selectionRect.width
        let currentH = selectionRect.height
        let newX = value.location.x / size.width - currentW / 2
        let newY = value.location.y / size.height - currentH / 2
        selectionRect.origin = CGPoint(x: max(0, min(1 - currentW, newX)), y: max(0, min(1 - currentH, newY)))
    }
    
    private func updateRect(corner: Corner, location: CGPoint, size: CGSize) {
        let nLoc = CGPoint(x: location.x / size.width, y: location.y / size.height)
        var r = selectionRect
        let minS: CGFloat = 0.05
        
        switch corner {
        case .topLeft:
            let newX = min(r.maxX - minS, max(0, nLoc.x))
            let newY = min(r.maxY - minS, max(0, nLoc.y))
            r = CGRect(x: newX, y: newY, width: r.maxX - newX, height: r.maxY - newY)
        case .topRight:
            let newMaxX = max(r.minX + minS, min(1, nLoc.x))
            let newY = min(r.maxY - minS, max(0, nLoc.y))
            r = CGRect(x: r.minX, y: newY, width: newMaxX - r.minX, height: r.maxY - newY)
        case .bottomLeft:
            let newX = min(r.maxX - minS, max(0, nLoc.x))
            let newMaxY = max(r.minY + minS, min(1, nLoc.y))
            r = CGRect(x: newX, y: r.minY, width: r.maxX - newX, height: newMaxY - r.minY)
        case .bottomRight:
            let newMaxX = max(r.minX + minS, min(1, nLoc.x))
            let newMaxY = max(r.minY + minS, min(1, nLoc.y))
            r = CGRect(x: r.minX, y: r.minY, width: newMaxX - r.minX, height: newMaxY - r.minY)
        }
        selectionRect = r
    }
    
    private func rectFromNormalized(_ norm: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: norm.minX * size.width, y: norm.minY * size.height, width: norm.width * size.width, height: norm.height * size.height)
    }
    
    private func cropImage(_ original: UIImage, normalizedRect: CGRect, viewSize: CGSize) -> UIImage {
        let imageRatio = original.size.width / original.size.height
        let viewRatio = viewSize.width / viewSize.height
        var renderRect = CGRect.zero
        
        if imageRatio > viewRatio {
            let scale = viewSize.width / original.size.width
            let height = original.size.height * scale
            renderRect = CGRect(x: 0, y: (viewSize.height - height) / 2, width: viewSize.width, height: height)
        } else {
            let scale = viewSize.height / original.size.height
            let width = original.size.width * scale
            renderRect = CGRect(x: (viewSize.width - width) / 2, y: 0, width: width, height: viewSize.height)
        }
        
        let selectionInView = rectFromNormalized(normalizedRect, in: viewSize)
        let intersection = selectionInView.intersection(renderRect)
        let scaleX = original.size.width / renderRect.width
        let scaleY = original.size.height / renderRect.height
        
        let cropRect = CGRect(
            x: (intersection.minX - renderRect.minX) * scaleX,
            y: (intersection.minY - renderRect.minY) * scaleY,
            width: intersection.width * scaleX,
            height: intersection.height * scaleY
        )
        
        if let cgImage = original.cgImage?.cropping(to: cropRect) {
            return UIImage(cgImage: cgImage, scale: original.scale, orientation: original.imageOrientation)
        }
        return original
    }
}

// MARK: - Selection Helpers

struct ResizeHandle: View {
    let at: CGPoint
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 32, height: 32)
            .shadow(radius: 2)
            .position(at)
    }
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
