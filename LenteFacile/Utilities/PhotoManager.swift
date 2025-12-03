//
//  PhotoManager.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 25/11/25.
//

import Photos
import UIKit

/// Gestore responsabile del salvataggio delle immagini nella Libreria Foto.
/// Gestisce i permessi e l'interazione con il framework Photos.
@MainActor
final class PhotoManager {
    
    static let shared = PhotoManager()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Tenta di salvare un'immagine nel rullino fotografico.
    /// Gestisce automaticamente la richiesta dei permessi.
    func saveImage(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        switch status {
        case .notDetermined:
            requestPermission { granted in
                if granted {
                    self.performSave(image, completion: completion)
                } else {
                    completion(false, nil)
                }
            }
        case .authorized, .limited:
            performSave(image, completion: completion)
        case .denied, .restricted:
            completion(false, nil) // L'utente deve abilitare da Impostazioni
        @unknown default:
            completion(false, nil)
        }
    }
    
    // MARK: - Private Logic
    
    private func requestPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                completion(status == .authorized || status == .limited)
            }
        }
    }
    
    private func performSave(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }
}
