import SwiftUI
import AVFoundation

struct CameraView: View {
    // MARK: - Dependencies
    @StateObject private var viewModel = CameraViewModel()
    @State private var appSettings = AppSettings.load()
    
    /// Simple mode (one big "LEGGI" button) is the default; advanced adds zoom, contrast and still photo.
    @AppStorage("advancedMode") private var advancedMode = false
    
    // MARK: - Local State
    @State private var freezeZoomFactor: CGFloat = 1.0
    @State private var visibleRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    @State private var showSettingsSheet = false
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 1. Content Layer (Live Camera or Frozen Image)
            contentLayer
            
            // 2. Controls
            if !viewModel.isReading {
                controlsLayer
            }
            
            // 3. "Hold still" countdown
            if viewModel.readPhase == .holdSteady {
                holdSteadyOverlay
                    .zIndex(150)
            }
            
            // 4. Reading screen
            if viewModel.isReading && !viewModel.scannedText.isEmpty {
                TranscriptionView(
                    text: viewModel.scannedText,
                    highlightRange: viewModel.highlightRange,
                    isPaused: viewModel.isSpeechPaused,
                    isVolumeLow: viewModel.isVolumeLow,
                    onTogglePause: { viewModel.togglePause() },
                    onClose: { viewModel.closeReading() }
                )
                .zIndex(200)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            
            // 5. Camera permission denied
            if viewModel.permissionDenied {
                cameraDeniedView
                    .zIndex(400)
            }
            
            // 6. OCR Processing Spinner
            if viewModel.isProcessingOCR {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("AccentColor")))
                            .scaleEffect(2)
                        Text("ui_reading_in_progress")
                            .font(.title2.weight(.bold))
                            .foregroundColor(.white)
                    }
                }
                .zIndex(300)
            }
            
        }
        .statusBar(hidden: true)
        .alert("camera_error_title", isPresented: $viewModel.showCaptureError) {
            Button("ui_ok", role: .cancel) { }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
        .onChange(of: showSettingsSheet) { _, isShowing in
            if !isShowing { appSettings = AppSettings.load() }
        }
        .onAppear {
            appSettings = AppSettings.load()
            viewModel.startCamera()
        }
        #if DEBUG
        .task { if DemoMode.isClip { await runDemoClip() } }
        #endif
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentLayer: some View {
        if viewModel.isFrozen, let image = viewModel.frozenDisplayImage ?? viewModel.frozenImage {
            FreezeView(image: image, zoomFactor: $freezeZoomFactor, visibleRect: $visibleRect)
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
        } else {
            liveLayer
        }
    }
    
    @ViewBuilder
    private var liveLayer: some View {
        #if DEBUG
        if let demo = viewModel.demoImage {
            DemoPreview(image: demo, mode: viewModel.contrastMode, zoom: viewModel.zoomFactor)
                .ignoresSafeArea()
        } else {
            cameraLayer
        }
        #else
        cameraLayer
        #endif
    }
    
    @ViewBuilder
    private var cameraLayer: some View {
        if let session = viewModel.session {
            Group {
                if viewModel.contrastMode == .normal {
                    CameraPreview(session: session)
                } else {
                    FilteredPreview(store: viewModel.frameStore)
                }
            }
            .ignoresSafeArea()
            .opacity(viewModel.permissionGranted ? 1 : 0)
        } else {
            Color.black.ignoresSafeArea()
        }
    }
    
    // MARK: - Controls
    
    @ViewBuilder
    private var controlsLayer: some View {
        if viewModel.readPhase != .idle {
            EmptyView()
        } else if viewModel.isFrozen {
            frozenControls
        } else if advancedMode {
            advancedControls
        } else {
            simpleControls
        }
    }
    
    /// "Move the phone away" warning: a picture (phone getting smaller) plus one word.
    private var distanceHint: some View {
        HStack(spacing: 14) {
            Image(systemName: "iphone.gen3").font(.system(size: 54, weight: .bold))
            Image(systemName: "arrow.right").font(.system(size: 34, weight: .black))
            Image(systemName: "iphone.gen3").font(.system(size: 30, weight: .bold))
            Text("hint_distance")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .foregroundColor(.black)
        .padding(.horizontal, 18).padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(Color("ButtonBackgroundPrimary"))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
    
    // Simple mode: one big button.
    private var simpleControls: some View {
        VStack(spacing: 12) {
            if viewModel.hint != nil { distanceHint }
            HStack {
                Spacer()
                PillButton(titleKey: "options", systemImage: "gearshape.fill") { showSettingsSheet = true }
                    .accessibilityLabel("ally_settings")
            }
            Spacer()
            BigActionButton(titleKey: "ui_read", systemImage: "speaker.wave.3.fill", height: 130) {
                viewModel.readFromLive()
            }
            .accessibilityLabel("ui_read")
            Button {
                HapticManager.shared.buttonTap()
                withAnimation { advancedMode = true }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color("ButtonBackground"))
                    .clipShape(Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .accessibilityLabel("more_functions")
        }
        .padding(.horizontal, 20)
        .padding(.top, 54)
        .padding(.bottom, 24)
    }
    
    // Advanced mode: zoom steps, contrast, still photo.
    private var advancedControls: some View {
        ZStack {
            VStack {
                HStack(spacing: 10) {
                    PillButton(titleKey: "simple_mode") {
                        withAnimation { advancedMode = false }
                    }
                    Button { viewModel.toggleTorch() } label: {
                        Image(systemName: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(viewModel.isTorchOn ? .black : .white)
                            .frame(width: 56, height: 56)
                            .background(viewModel.isTorchOn ? Color("ButtonBackgroundPrimary") : Color.black.opacity(0.85))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(viewModel.isTorchOn ? "ally_torch_off" : "ally_torch_on")
                    Spacer()
                    PillButton(titleKey: "options") { showSettingsSheet = true }
                        .accessibilityLabel("ally_settings")
                }
                .padding(.horizontal, 16)
                .padding(.top, 54)
                
                if viewModel.hint != nil { distanceHint.padding(.horizontal, 16) }
                
                Spacer()
                
                ZoomPresets(value: $viewModel.zoomFactor)
                    .padding(.horizontal, 16)
                
                HStack(alignment: .bottom) {
                    LabeledCircleButton(systemImage: "circle.lefthalf.filled", labelKey: "contrast") {
                        viewModel.cycleContrast()
                    }
                    Spacer()
                    LabeledCircleButton(systemImage: "record.circle", labelKey: "ui_shoot", size: 112, isPrimary: true) {
                        viewModel.toggleFreeze()
                    }
                    Spacer()
                    LabeledCircleButton(systemImage: "speaker.wave.3.fill", labelKey: "ui_read_title") {
                        viewModel.readFromLive()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .background(bottomGradient)
            
            if viewModel.showContrastToast {
                Text(LocalizedStringKey(viewModel.contrastMode.titleKey))
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(Color("ButtonBackgroundPrimary"))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color("ButtonBackgroundPrimary"), lineWidth: 4))
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 30)
                .transition(.scale.combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showContrastToast)
    }
    
    // Frozen photo: magnify with steps, read it, save it, or leave.
    private var frozenControls: some View {
        VStack {
            Text("photo_frozen")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color("ButtonBackgroundPrimary"))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 16)
                .padding(.top, 54)
            
            Spacer()
            
            ZoomPresets(value: $freezeZoomFactor, steps: [2, 4, 8])
                .padding(.horizontal, 16)
            
            HStack(alignment: .bottom) {
                LabeledCircleButton(systemImage: "arrow.uturn.backward", labelKey: "ui_exit") {
                    freezeZoomFactor = 1.0
                    visibleRect = CGRect(x: 0, y: 0, width: 1, height: 1)
                    viewModel.toggleFreeze()
                }
                Spacer()
                LabeledCircleButton(systemImage: "speaker.wave.3.fill", labelKey: "ui_read_title", size: 112, isPrimary: true) {
                    viewModel.readFrozenImage(visibleRect: visibleRect)
                }
                Spacer()
                LabeledCircleButton(systemImage: "square.and.arrow.down", labelKey: "ui_save_title") {
                    savePhoto()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(bottomGradient)
    }
    
    private var bottomGradient: some View {
        VStack {
            Spacer()
            LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                .frame(height: 380)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
    
    // MARK: - Hold still
    
    private var holdSteadyOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 26) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(Color("ButtonBackgroundPrimary"))
                    .padding(22)
                    .background(Circle().fill(Color.black.opacity(0.8)))
                
                Text("\(viewModel.steadyCountdown)")
                    .font(.system(size: 90, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 200)
                    .background(Circle().fill(Color.black.opacity(0.75)))
                    .overlay(Circle().trim(from: 0, to: 0.7).stroke(Color("ButtonBackgroundPrimary"), lineWidth: 14).rotationEffect(.degrees(-90)))
                
                Spacer()
                
                BigActionButton(titleKey: "ui_cancel", systemImage: "xmark", height: 80, style: .dark) {
                    viewModel.cancelRead()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 70)
            .padding(.bottom, 24)
        }
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Camera permission denied
    
    /// Shown when camera access was denied: explains why and links to the Settings app.
    var cameraDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundColor(Color("AccentColor"))
                .accessibilityHidden(true)
            Text("camera_denied_title")
                .font(.title.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("camera_denied_open_settings")
                    .font(.title3.bold())
                    .foregroundColor(.black)
                    .padding(.vertical, 16).padding(.horizontal, 28)
                    .background(Color("ButtonBackgroundPrimary"))
                    .clipShape(Capsule())
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
    
    // MARK: - Actions
    
    private func savePhoto() {
        guard let image = viewModel.frozenDisplayImage ?? viewModel.frozenImage else { return }
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

/// Shows camera frames already processed with a contrast filter.
struct FilteredPreview: UIViewRepresentable {
    @ObservedObject var store: FrameStore
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.contentsGravity = .resizeAspectFill
        view.layer.masksToBounds = true
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.layer.contents = store.image
    }
}

#if DEBUG
/// Stands in for the camera view when recording on the simulator.
private struct DemoPreview: View {
    let image: UIImage
    let mode: ContrastMode
    let zoom: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            Image(uiImage: ContrastMode.apply(mode, to: image))
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(max(1, zoom / 2.5))
                .clipped()
        }
    }
}

extension CameraView {
    /// Paced tour used to record the README clip: simple mode and reading, then advanced mode.
    @MainActor
    fileprivate func runDemoClip() async {
        func wait(_ seconds: Double) async { try? await Task.sleep(for: .seconds(seconds)) }
        advancedMode = false
        await wait(3)
        viewModel.readFromLive()
        await wait(7)
        // The simulator's speech voices are unreliable. If the voice did not start by itself,
        // walk the highlight over the words so the clip shows the screen as it looks on a phone.
        if viewModel.highlightRange == nil, viewModel.isReading {
            let text = viewModel.scannedText as NSString
            var words: [NSRange] = []
            text.enumerateSubstrings(in: NSRange(location: 0, length: text.length), options: .byWords) { _, range, _, _ in
                words.append(range)
            }
            for range in words.prefix(60) {
                viewModel.highlightRange = range
                await wait(0.28)
            }
        } else {
            await wait(10)
        }
        viewModel.closeReading()
        await wait(1.5)
        withAnimation { advancedMode = true }
        await wait(1.5)
        viewModel.zoomFactor = 4
        await wait(1.5)
        for _ in 0..<4 {                       // white, yellow, black on white, back to normal
            viewModel.cycleContrast()
            await wait(2)
        }
        viewModel.cycleContrast()              // leave yellow on black for the still photo
        viewModel.cycleContrast()
        await wait(1.5)
        viewModel.toggleFreeze()
        await wait(2)
        withAnimation { freezeZoomFactor = 2 }
        await wait(3)
    }
}
#endif
