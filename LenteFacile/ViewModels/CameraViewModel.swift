//
//  CameraViewModel.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 24/11/25.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - Camera Service (Background Logic)

/// Gestisce la complessità di AVFoundation su una coda seriale dedicata.
/// Marcato @unchecked Sendable per gestire manualmente la thread-safety di oggetti non-Sendable (AVCaptureSession, ecc).
private final class CameraService: NSObject, @unchecked Sendable {
    
    // Queue seriale per evitare blocchi del Main Thread
    private let sessionQueue = DispatchQueue(label: "com.lentesemplice.cameraSession")
    
    private var session: AVCaptureSession?
    private var output = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    // Callback verso il ViewModel (eseguiti su MainActor)
    var onSessionReady: ((AVCaptureSession) -> Void)?
    var onPhotoCaptured: ((UIImage) -> Void)?
    var onError: ((Error) -> Void)?
    
    // Settings
    private var magSettings = MagnificationSettings.load()
    
    override init() {
        super.init()
    }
    
    func start() {
        checkPermissions()
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            self?.session?.stopRunning()
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
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.setupCamera() }
            }
        default:
            // Gestire caso negato se necessario
            break
        }
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newSession = AVCaptureSession()
            newSession.beginConfiguration()
            newSession.sessionPreset = .photo // Preset Photo gestisce alta risoluzione automaticamente
            
            // Input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: videoDevice)
                if newSession.canAddInput(input) {
                    newSession.addInput(input)
                    self.videoDeviceInput = input
                }
                
                // Output
                if newSession.canAddOutput(self.output) {
                    newSession.addOutput(self.output)
                    // Nota: isHighResolutionCaptureEnabled è deprecato in iOS 16+.
                    // Il preset .photo e le impostazioni di scatto gestiscono la qualità.
                    // Impostiamo maxPhotoDimensions usando le dimensioni dal formato attivo.
                    let dims = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription)
                    if dims.width > 0 && dims.height > 0 {
                        self.output.maxPhotoDimensions = dims
                    }
                }
                
            } catch {
                print("CameraService Error: \(error)")
                self.notifyError(error)
            }
            
            newSession.commitConfiguration()
            newSession.startRunning()
            self.session = newSession
            
            // Zoom Iniziale
            self.internalSetZoom(factor: self.magSettings.startingZoom)
            
            // Notifica ViewModel
            DispatchQueue.main.async {
                self.onSessionReady?(newSession)
            }
        }
    }
    
    // MARK: - Actions
    
    func setZoom(factor: CGFloat) {
        sessionQueue.async { [weak self] in
            self?.internalSetZoom(factor: factor)
        }
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
            
            // Salva preferenza (fire & forget)
            Task { @MainActor in
                if self.magSettings.rememberLastZoom {
                    self.magSettings.updateLastUsedZoom(effectiveZoom)
                    self.magSettings.save()
                }
            }
        } catch {
            print("Zoom Error: \(error)")
        }
    }
    
    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            // Richiediamo alta risoluzione se supportata dal formato
            if self.output.maxPhotoDimensions.width > 0 {
                settings.maxPhotoDimensions = self.output.maxPhotoDimensions
            }
            
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }
    
    nonisolated private func notifyError(_ error: Error) {
        DispatchQueue.main.async { self.onError?(error) }
    }
}

// MARK: - AVCaptureDelegate (Background)

// Make the conformance explicitly nonisolated so it can be used from the sessionQueue.
nonisolated extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            notifyError(error)
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        
        // Esegui la normalizzazione dell'orientamento sul MainActor (UIKit drawing è @MainActor)
        DispatchQueue.main.async {
            let fixedImage = image.fixOrientation()
            self.onPhotoCaptured?(fixedImage)
        }
    }
}

// MARK: - ViewModel (MainActor UI Logic)

@MainActor
final class CameraViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var session: AVCaptureSession?
    @Published var zoomFactor: CGFloat = 1.0 {
        didSet {
            // Evita loop infiniti se aggiornato internamente, ma qui zoomFactor guida il servizio
            service.setZoom(factor: zoomFactor)
        }
    }
    
    @Published var isFrozen: Bool = false
    @Published var frozenImage: UIImage?
    @Published var permissionGranted: Bool = false // Semplificato per UI
    
    // MARK: - Dependencies
    private let service = CameraService()
    
    // MARK: - Init
    init() {
        setupBindings()
        service.start()
        
        // Sync iniziale zoom visuale
        let initialSettings = MagnificationSettings.load()
        self.zoomFactor = initialSettings.startingZoom
        self.permissionGranted = true // Assunto true mentre carichiamo, gestito meglio dallo stato sessione
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
            print("Camera Error: \(error)")
        }
    }
    
    // MARK: - Logic
    
    func toggleFreeze() {
        if isFrozen {
            unfreeze()
        } else {
            HapticManager.shared.buttonTap()
            service.capturePhoto() // Scatta foto per il freeze
        }
    }
    
    private func handlePhotoCaptured(_ image: UIImage) {
        self.frozenImage = image
        withAnimation {
            self.isFrozen = true
        }
        
        HapticManager.shared.freezeActivated()
        AudioManager.shared.playFreezeSound()
        
        // Stop sessione live per risparmio risorse
        service.stop()
    }
    
    private func unfreeze() {
        withAnimation {
            isFrozen = false
            frozenImage = nil
        }
        
        HapticManager.shared.freezeDeactivated()
        AudioManager.shared.playUnfreezeSound()
        
        // Riavvia sessione live
        service.resume()
    }
}

// MARK: - Image Helper (Pure Extension)

extension UIImage {
    /// Corregge l'orientamento dell'immagine (Pure Function, Thread Safe)
    func fixOrientation() -> UIImage {
        if self.imageOrientation == .up { return self }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}

