import SwiftUI
import AVFoundation
import Combine

// MARK: - Live frames with a contrast filter

/// Receives camera frames and, when a contrast mode is active, renders the filtered frame.
nonisolated final class VideoFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var _mode: ContrastMode = .normal
    private let ciContext = CIContext()
    var onFrame: (@Sendable (CGImage) -> Void)?

    var mode: ContrastMode {
        get { lock.lock(); defer { lock.unlock() }; return _mode }
        set { lock.lock(); _mode = newValue; lock.unlock() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let current = mode
        guard current != .normal, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let filtered = current.apply(to: CIImage(cvPixelBuffer: buffer))
        if let cg = ciContext.createCGImage(filtered, from: filtered.extent) { onFrame?(cg) }
    }
}

/// Holds the latest filtered frame separately from the view model, so that
/// 30 frames/second do not re-render the whole screen.
final class FrameStore: ObservableObject {
    @Published var image: CGImage?
}

// MARK: - Camera Service (Background Logic)

/// Manages AVFoundation complexity on a dedicated serial queue.
private final class CameraService: NSObject, @unchecked Sendable {
    
    private let sessionQueue = DispatchQueue(label: "com.GrandmEye.cameraSession")
    private let videoQueue = DispatchQueue(label: "com.GrandmEye.videoFrames")
    private var session: AVCaptureSession?
    private var output = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    let frameProcessor = VideoFrameProcessor()
    
    var onSessionReady: ((AVCaptureSession) -> Void)?
    var onPhotoCaptured: ((UIImage) -> Void)?
    var onError: ((Error) -> Void)?
    var onPermissionDenied: (() -> Void)?
    var onCaptureFailed: (() -> Void)?
    
    private var magSettings = MagnificationSettings.load()
    
    override init() {
        super.init()
    }
    
    // MARK: - Lifecycle
    
    func start() { checkPermissions() }
    
    func stop() {
        sessionQueue.async { [weak self] in
            self?.session?.stopRunning()
            self?.internalSetTorch(on: false)
        }
    }
    
    func resume() {
        sessionQueue.async { [weak self] in
            if let session = self?.session, !session.isRunning {
                session.startRunning()
            }
        }
    }
    
    // MARK: - Permissions & Setup
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupCamera()
                } else {
                    DispatchQueue.main.async { self?.onPermissionDenied?() }
                }
            }
        default:
            // .denied or .restricted: tell the UI so it can guide the user to Settings.
            DispatchQueue.main.async { self.onPermissionDenied?() }
        }
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let newSession = AVCaptureSession()
            newSession.beginConfiguration()
            newSession.sessionPreset = .photo
            
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
            
            do {
                let input = try AVCaptureDeviceInput(device: videoDevice)
                if newSession.canAddInput(input) {
                    newSession.addInput(input)
                    self.videoDeviceInput = input
                }
                if newSession.canAddOutput(self.output) {
                    newSession.addOutput(self.output)
                    if let maxDims = videoDevice.activeFormat.supportedMaxPhotoDimensions.last {
                        self.output.maxPhotoDimensions = maxDims
                    }
                }
                // Frames for the live contrast filter.
                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                self.videoOutput.setSampleBufferDelegate(self.frameProcessor, queue: self.videoQueue)
                if newSession.canAddOutput(self.videoOutput) {
                    newSession.addOutput(self.videoOutput)
                    self.videoOutput.connection(with: .video)?.videoRotationAngle = 90
                }
                self.configureFocus(videoDevice)
            } catch {
                print("CameraService Error: \(error)")
                self.notifyError(error)
            }
            
            newSession.commitConfiguration()
            newSession.startRunning()
            self.session = newSession
            self.internalSetZoom(factor: self.magSettings.startingZoom)
            
            DispatchQueue.main.async { self.onSessionReady?(newSession) }
        }
    }
    
    /// Continuous autofocus tuned for close reading.
    private func configureFocus(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
            device.unlockForConfiguration()
        } catch { print("Focus config error: \(error)") }
    }
    
    // MARK: - Actions
    
    func setZoom(factor: CGFloat) {
        sessionQueue.async { [weak self] in self?.internalSetZoom(factor: factor) }
    }
    
    func setTorch(on: Bool) {
        sessionQueue.async { [weak self] in self?.internalSetTorch(on: on) }
    }
    
    func setContrast(_ mode: ContrastMode) {
        frameProcessor.mode = mode
    }
    
    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            if self.output.maxPhotoDimensions.width > 0 {
                settings.maxPhotoDimensions = self.output.maxPhotoDimensions
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }
    
    // MARK: - Internal Helpers
    
    private func internalSetTorch(on: Bool) {
        guard let device = videoDeviceInput?.device, device.hasTorch, device.isTorchAvailable else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            if on { try device.setTorchModeOn(level: 1.0) }
            device.unlockForConfiguration()
        } catch { print("Torch error: \(error)") }
    }
    
    private func internalSetZoom(factor: CGFloat) {
        guard let input = self.videoDeviceInput else { return }
        let device = input.device
        do {
            try device.lockForConfiguration()
            let maxDeviceZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
            let effectiveZoom = max(1.0, min(factor, maxDeviceZoom))
            device.videoZoomFactor = effectiveZoom
            device.unlockForConfiguration()
            Task { @MainActor in
                if self.magSettings.rememberLastZoom {
                    self.magSettings.updateLastUsedZoom(effectiveZoom)
                    self.magSettings.save()
                }
            }
        } catch { print("Zoom Error: \(error)") }
    }
    
    private func notifyError(_ error: Error) {
        DispatchQueue.main.async { self.onError?(error) }
    }
}

// MARK: - AVCaptureDelegate

nonisolated extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.onCaptureFailed?() }
            return
        }
        let fixedImage = image.fixOrientation()
        DispatchQueue.main.async { self.onPhotoCaptured?(fixedImage) }
    }
}

// MARK: - ViewModel (MainActor Logic)

@MainActor
final class CameraViewModel: ObservableObject {
    
    /// What the camera is doing on behalf of the "Leggi" button.
    enum ReadPhase: Equatable {
        case idle
        case holdSteady     // waiting for the phone to stop moving
        case processing     // photo taken, running OCR
    }
    
    /// Why the last read attempt did not work.
    enum Hint { case moveAway }
    
    @Published var session: AVCaptureSession?
    @Published var zoomFactor: CGFloat = 1.0 { didSet { service.setZoom(factor: zoomFactor) } }
    @Published var isTorchOn: Bool = false
    @Published var isFrozen: Bool = false
    @Published var frozenImage: UIImage?
    /// The frozen photo with the active contrast mode applied (what the user sees).
    @Published var frozenDisplayImage: UIImage?
    @Published var permissionGranted: Bool = false
    @Published var permissionDenied: Bool = false
    @Published var showCaptureError: Bool = false
    
    // Contrast
    @Published var contrastMode: ContrastMode = .loadSaved()
    @Published var showContrastToast: Bool = false
    
    // "Leggi" flow
    @Published var readPhase: ReadPhase = .idle
    @Published var steadyCountdown: Int = 2
    @Published var hint: Hint?
    
    // OCR & Reading State
    @Published var isReading: Bool = false
    @Published var isProcessingOCR: Bool = false
    @Published var scannedText: String = ""
    @Published var highlightRange: NSRange?
    @Published var isSpeechPaused: Bool = false
    @Published var isVolumeLow: Bool = false
    
    let frameStore = FrameStore()
    
    private let service = CameraService()
    private let steadiness = SteadinessMonitor()
    private var readTask: Task<Void, Never>?
    private var hintTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var volumeObserver: NSKeyValueObservation?
    private var cameraStarted = false
    private var captureIntent: CaptureIntent = .freeze
    private var languageCode: String { AppSettings.load().languageCode }
    
    private enum CaptureIntent { case freeze, read }
    
    init() {
        let initialSettings = MagnificationSettings.load()
        self.zoomFactor = initialSettings.startingZoom
        setupBindings()
        service.setContrast(contrastMode)
        OCRManager.shared.onSpeechDidFinish = { }
        OCRManager.shared.onWillSpeakWord = { [weak self] range in
            self?.highlightRange = range
        }
    }
    
    /// Starts the camera (and so asks for permission). Called after the welcome screen.
    func startCamera() {
        guard !cameraStarted else { return }
        cameraStarted = true
        service.start()
    }
    
    private func setupBindings() {
        service.onSessionReady = { [weak self] session in
            self?.session = session
            self?.permissionGranted = true
        }
        service.onPhotoCaptured = { [weak self] image in
            self?.handlePhotoCaptured(image)
        }
        service.onError = { [weak self] _ in
            HapticManager.shared.error()
            self?.showCaptureError = true
        }
        service.onPermissionDenied = { [weak self] in
            self?.permissionDenied = true
        }
        service.onCaptureFailed = { [weak self] in
            HapticManager.shared.error()
            self?.readPhase = .idle
            self?.showCaptureError = true
        }
        service.frameProcessor.onFrame = { [weak self] cgImage in
            DispatchQueue.main.async { self?.frameStore.image = cgImage }
        }
    }
    
    // MARK: - Actions
    
    func toggleTorch() {
        HapticManager.shared.buttonTap()
        isTorchOn.toggle()
        service.setTorch(on: isTorchOn)
    }
    
    /// Cycles normal → white on black → yellow on black → black on white.
    func cycleContrast() {
        contrastMode = contrastMode.next
        contrastMode.save()
        service.setContrast(contrastMode)
        if contrastMode == .normal { frameStore.image = nil }
        refreshFrozenDisplay()
        showContrastToast = true
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            if !Task.isCancelled { showContrastToast = false }
        }
    }
    
    /// "Scatta": freezes the picture so it can be inspected and magnified.
    func toggleFreeze() {
        if isFrozen {
            unfreeze()
        } else {
            HapticManager.shared.buttonTap()
            captureIntent = .freeze
            service.capturePhoto()
        }
    }
    
    // MARK: - "Leggi" from the live camera
    
    /// Waits until the phone is steady, takes a photo by itself, then reads it.
    func readFromLive() {
        guard readPhase == .idle, !isFrozen else { return }
        HapticManager.shared.buttonTap()
        clearHint()
        readPhase = .holdSteady
        steadyCountdown = 2
        readTask?.cancel()
        readTask = Task {
            await waitUntilSteady()
            guard !Task.isCancelled else { return }
            captureIntent = .read
            readPhase = .processing
            service.capturePhoto()
        }
    }
    
    func cancelRead() {
        readTask?.cancel()
        steadiness.stop()
        readPhase = .idle
        HapticManager.shared.buttonTap()
    }
    
    private func waitUntilSteady() async {
        let required = 1.5      // seconds the phone must stay still
        let timeout = 8.0       // never wait forever (e.g. a strong tremor)
        steadiness.start()
        defer { steadiness.stop() }
        var steadyFor = 0.0
        var elapsed = 0.0
        while elapsed < timeout && steadyFor < required {
            try? await Task.sleep(for: .milliseconds(100))
            if Task.isCancelled { return }
            elapsed += 0.1
            // Without motion sensors (simulator) simply wait the required time.
            let isSteadyNow = steadiness.isAvailable ? steadiness.isSteady : true
            steadyFor = isSteadyNow ? steadyFor + 0.1 : 0
            steadyCountdown = max(1, Int((required - steadyFor).rounded(.up)))
        }
    }
    
    // MARK: - Reading
    
    /// Reads the whole picture aloud. `fromLive` controls what happens when nothing readable is found.
    func startReading(image: UIImage, fromLive: Bool = false) {
        HapticManager.shared.buttonTap()
        isProcessingOCR = true
        scannedText = ""
        highlightRange = nil
        isSpeechPaused = false
        
        let code = languageCode
        Task {
            let result = await OCRManager.shared.recognizeText(in: image, languageCode: code)
            isProcessingOCR = false
            readPhase = .idle
            
            // Too little text or too unsure: most likely too close, out of focus or shaky.
            guard let result, result.confidence >= 0.3 else {
                HapticManager.shared.error()
                if fromLive {
                    showHint(.moveAway)
                } else {
                    OCRManager.shared.speak(String.localized("ocr_no_text", languageCode: code), languageCode: code)
                }
                return
            }
            
            let normalized = OCRManager.shared.normalizeText(result.text, languageCode: code)
            scannedText = normalized
            isReading = true
            OCRManager.shared.speak(normalized, languageCode: code)
            watchVolume()
        }
    }
    
    /// Reads only the part of the frozen photo that is on screen (after zoom and move).
    func readFrozenImage(visibleRect: CGRect) {
        guard let image = frozenImage else { return }
        startReading(image: Self.crop(image, to: visibleRect))
    }
    
    /// Crops an image to a normalized rectangle (origin top-left). Returns the image itself if almost everything is visible.
    private static func crop(_ image: UIImage, to normalized: CGRect) -> UIImage {
        guard let cg = image.cgImage else { return image }
        if normalized.width > 0.98 && normalized.height > 0.98 { return image }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let rect = CGRect(x: normalized.minX * w, y: normalized.minY * h,
                          width: normalized.width * w, height: normalized.height * h).integral
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard rect.width > 8, rect.height > 8, let cropped = cg.cropping(to: rect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
    
    func closeReading() {
        isReading = false
        isSpeechPaused = false
        highlightRange = nil
        OCRManager.shared.stop()
        volumeObserver = nil
        HapticManager.shared.buttonTap()
    }
    
    func togglePause() {
        HapticManager.shared.buttonTap()
        if isSpeechPaused {
            OCRManager.shared.resume()
        } else {
            OCRManager.shared.pause()
        }
        isSpeechPaused.toggle()
    }
    
    private func watchVolume() {
        isVolumeLow = OCRManager.shared.outputVolume < 0.25
        volumeObserver = AVAudioSession.sharedInstance().observe(\.outputVolume) { [weak self] session, _ in
            let volume = session.outputVolume
            Task { @MainActor in self?.isVolumeLow = volume < 0.25 }
        }
    }
    
    // MARK: - Hint ("Allontana un po' il telefono")
    
    private func showHint(_ newHint: Hint) {
        hint = newHint
        let code = languageCode
        OCRManager.shared.speak(String.localized("hint_distance", languageCode: code), languageCode: code)
        hintTask?.cancel()
        hintTask = Task {
            try? await Task.sleep(for: .seconds(8))
            if !Task.isCancelled { hint = nil }
        }
    }
    
    private func clearHint() {
        hintTask?.cancel()
        hint = nil
    }
    
    // MARK: - Private Logic
    
    private func handlePhotoCaptured(_ image: UIImage) {
        switch captureIntent {
        case .read:
            captureIntent = .freeze
            startReading(image: image, fromLive: true)
        case .freeze:
            self.frozenImage = image
            self.frozenDisplayImage = image
            refreshFrozenDisplay()
            withAnimation { self.isFrozen = true }
            
            // Turn off torch when freezing to save battery
            if isTorchOn {
                isTorchOn = false
                service.setTorch(on: false)
            }
            
            HapticManager.shared.freezeActivated()
            AudioManager.shared.playFreezeSound()
            service.stop()
        }
    }
    
    /// Re-applies the contrast mode to the frozen photo (off the main thread: the photo is large).
    private func refreshFrozenDisplay() {
        guard let original = frozenImage else { return }
        let mode = contrastMode
        Task {
            let filtered = await Task.detached(priority: .userInitiated) {
                ContrastMode.apply(mode, to: original)
            }.value
            if self.frozenImage === original { self.frozenDisplayImage = filtered }
        }
    }
    
    private func unfreeze() {
        closeReading()
        withAnimation {
            isFrozen = false
            frozenImage = nil
            frozenDisplayImage = nil
            scannedText = ""
        }
        HapticManager.shared.freezeActivated()
        AudioManager.shared.playUnfreezeSound()
        service.resume()
    }
}
