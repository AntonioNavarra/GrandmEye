//
//  CameraViewModel.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 24/11/25.
//

import SwiftUI
import AVFoundation
import Combine

/// Gestisce la logica della fotocamera, lo zoom e la cattura.
/// FIX: Risolve i warning di Swift 6 sulla concorrenza e l'isolamento degli attori.
@MainActor
final class CameraViewModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties (MainActor)
    
    /// La sessione è opzionale per evitare accessi prima della configurazione
    @Published var session: AVCaptureSession?
    
    @Published var zoomFactor: CGFloat = 1.0 {
        didSet {
            updateDeviceZoom(factor: zoomFactor)
        }
    }
    
    @Published var isFrozen: Bool = false
    @Published var frozenImage: UIImage?
    @Published var permissionGranted: Bool = false
    
    // MARK: - Private Properties
    
    private let output = AVCapturePhotoOutput()
    // videoDeviceInput non è thread-safe, lo gestiamo con cautela dentro la queue
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    // Coda seriale per le operazioni AVFoundation (Background)
    private let sessionQueue = DispatchQueue(label: "com.lentesemplice.cameraSession")
    
    private var magSettings = MagnificationSettings.load()
    
    // MARK: - Init
    override init() {
        super.init()
        self.zoomFactor = magSettings.startingZoom
        checkPermissions()
    }
    
    // MARK: - Setup
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            permissionGranted = false
        }
    }
    
    private func setupCamera() {
        // Eseguiamo la configurazione pesante in background
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Creiamo una NUOVA sessione locale (non quella del MainActor)
            let newSession = AVCaptureSession()
            newSession.beginConfiguration()
            newSession.sessionPreset = .photo
            
            // 2. Configuriamo Input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                print("CameraVM: Nessuna camera posteriore trovata")
                newSession.commitConfiguration()
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: videoDevice)
                if newSession.canAddInput(input) {
                    newSession.addInput(input)
                    self.videoDeviceInput = input // Salviamo riferimento per lo zoom
                }
                
                // 3. Configuriamo Output
                if newSession.canAddOutput(self.output) {
                    newSession.addOutput(self.output)
                    self.output.isHighResolutionCaptureEnabled = true
                }
                
            } catch {
                print("CameraVM: Errore input device: \(error)")
            }
            
            newSession.commitConfiguration()
            newSession.startRunning()
            
            // 4. Assegniamo la sessione pronta alla proprietà @Published sul MainActor
            Task { @MainActor in
                self.session = newSession
                // Ripristiniamo lo zoom iniziale
                self.updateDeviceZoom(factor: self.magSettings.startingZoom)
            }
        }
    }
    
    // MARK: - Zoom Control
    
    private func updateDeviceZoom(factor: CGFloat) {
        sessionQueue.async { [weak self] in
            // Accediamo all'input salvato nella queue
            guard let self = self, let input = self.videoDeviceInput else { return }
            let device = input.device
            
            do {
                try device.lockForConfiguration()
                
                let maxDeviceZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
                let effectiveZoom = max(1.0, min(factor, maxDeviceZoom))
                
                device.videoZoomFactor = effectiveZoom
                device.unlockForConfiguration()
                
                // Salvataggio preferenze (torniamo su MainActor)
                Task { @MainActor in
                    if self.magSettings.rememberLastZoom {
                        self.magSettings.updateLastUsedZoom(effectiveZoom)
                        self.magSettings.save()
                    }
                }
            } catch {
                print("CameraVM: Errore zoom: \(error)")
            }
        }
    }
    
    // MARK: - Freeze Logic
    
    func toggleFreeze() {
        if isFrozen {
            unfreeze()
        } else {
            captureForFreeze()
        }
    }
    
    private func captureForFreeze() {
        HapticManager.shared.buttonTap()
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            // output è stato creato all'init, sicuro usarlo qui
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }
    
    private func unfreeze() {
        withAnimation {
            isFrozen = false
            frozenImage = nil
        }
        
        HapticManager.shared.freezeDeactivated()
        AudioManager.shared.playUnfreezeSound()
        
        // Riavvia sessione
        sessionQueue.async { [weak self] in
            guard let self = self, let session = self.session else { return }
            if !session.isRunning {
                session.startRunning()
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
// L'estensione deve conformarsi al delegato. I metodi del delegato sono chiamati su un thread arbitrario.
extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("CameraVM: Errore cattura: \(error)")
            Task { @MainActor in HapticManager.shared.error() }
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        
        // Fix orientamento immagine
        let fixedImage = image.fixOrientation()
        
        Task { @MainActor in
            self.frozenImage = fixedImage
            withAnimation {
                self.isFrozen = true
            }
            
            HapticManager.shared.freezeActivated()
            AudioManager.shared.playFreezeSound()
            
            // Stop sessione per risparmio batteria
            self.sessionQueue.async { [weak self] in
                self?.session?.stopRunning()
            }
        }
    }
}

// MARK: - Helper Extension
extension UIImage {
    func fixOrientation() -> UIImage {
        if self.imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? self
    }
}
