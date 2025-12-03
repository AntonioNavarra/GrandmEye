//
//  CameraViewModel.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 24/11/25.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Camera Service (Logica Background)

/// Gestisce la complessità di AVFoundation su una coda seriale dedicata.
private final class CameraService: NSObject, @unchecked Sendable {
    
    private let sessionQueue = DispatchQueue(label: "com.lentesemplice.cameraSession")
    private var session: AVCaptureSession?
    private var output = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    var onSessionReady: ((AVCaptureSession) -> Void)?
    var onPhotoCaptured: ((UIImage) -> Void)?
    var onError: ((Error) -> Void)?
    
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
                if granted { self?.setupCamera() }
            }
        default: break
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
    
    // MARK: - Actions
    
    func setZoom(factor: CGFloat) {
        sessionQueue.async { [weak self] in self?.internalSetZoom(factor: factor) }
    }
    
    func setTorch(on: Bool) {
        sessionQueue.async { [weak self] in self?.internalSetTorch(on: on) }
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

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        let fixedImage = image.fixOrientation()
        DispatchQueue.main.async { self.onPhotoCaptured?(fixedImage) }
    }
}

// MARK: - ViewModel (MainActor Logic)

@MainActor
final class CameraViewModel: ObservableObject {
    
    @Published var session: AVCaptureSession?
    @Published var zoomFactor: CGFloat = 1.0 { didSet { service.setZoom(factor: zoomFactor) } }
    @Published var isTorchOn: Bool = false
    @Published var isFrozen: Bool = false
    @Published var frozenImage: UIImage?
    @Published var permissionGranted: Bool = false
    
    // OCR State
    @Published var isReading: Bool = false
    @Published var isProcessingOCR: Bool = false
    @Published var scannedText: String = ""
    
    private let service = CameraService()
    
    init() {
        let initialSettings = MagnificationSettings.load()
        self.zoomFactor = initialSettings.startingZoom
        setupBindings()
        service.start()
        
        // Non chiudere automaticamente il note alla fine della lettura
        OCRManager.shared.onSpeechDidFinish = { }
    }
    
    private func setupBindings() {
        service.onSessionReady = { [weak self] session in
            self?.session = session
            self?.permissionGranted = true
        }
        service.onPhotoCaptured = { [weak self] image in
            self?.handlePhotoCaptured(image)
        }
        service.onError = { error in
            HapticManager.shared.error()
        }
    }
    
    // MARK: - Actions
    
    func toggleTorch() {
        HapticManager.shared.buttonTap()
        isTorchOn.toggle()
        service.setTorch(on: isTorchOn)
    }
    
    func toggleFreeze() {
        if isFrozen {
            unfreeze()
        } else {
            HapticManager.shared.buttonTap()
            service.capturePhoto()
        }
    }
    
    func stopReading() {
        isReading = false
        OCRManager.shared.stop()
        HapticManager.shared.buttonTap()
    }
    
    func startReading(croppedImage: UIImage) {
        HapticManager.shared.buttonTap()
        isProcessingOCR = true
        scannedText = ""
        
        Task {
            // 1. Riconoscimento testo grezzo
            let rawText = await OCRManager.shared.recognizeText(in: croppedImage)
            
            if let text = rawText {
                // 2. Normalizzazione Intelligente (Date, Prezzi)
                let normalizedText = OCRManager.shared.normalizeText(text)
                
                // 3. Aggiorna UI (Mostra foglietto SOLO con testo originale normalizzato)
                // Rimossa logica di traduzione
                self.scannedText = normalizedText
                self.isProcessingOCR = false
                self.isReading = true
                
                // 4. Parla
                OCRManager.shared.speak(normalizedText)
            } else {
                self.isProcessingOCR = false
                HapticManager.shared.error()
                OCRManager.shared.speak("Nessun testo trovato.")
            }
        }
    }
    
    // MARK: - Private Logic
    
    private func handlePhotoCaptured(_ image: UIImage) {
        self.frozenImage = image
        withAnimation { self.isFrozen = true }
        if isTorchOn {
            isTorchOn = false
            service.setTorch(on: false)
        }
        HapticManager.shared.freezeActivated()
        AudioManager.shared.playFreezeSound()
        service.stop()
    }
    
    private func unfreeze() {
        stopReading()
        withAnimation {
            isFrozen = false
            frozenImage = nil
            scannedText = ""
        }
        HapticManager.shared.freezeDeactivated()
        AudioManager.shared.playUnfreezeSound()
        service.resume()
    }
}
