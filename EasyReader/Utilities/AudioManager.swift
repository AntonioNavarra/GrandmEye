//
//  AudioManager.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 24/11/25.
//

import AVFoundation
import UIKit

/// Gestore centralizzato per il feedback sonoro.
/// Utilizza AudioServices per suoni di sistema (più performanti per UI)
/// e AVAudioPlayer se dovessimo implementare file custom in futuro.
@MainActor
final class AudioManager {
    
    // MARK: - Singleton
    static let shared = AudioManager()
    
    // MARK: - Properties
    private var isEnabled: Bool = true
    private var volume: Float = 0.7
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            // Categoria Ambient per non interrompere musica in background (es. Spotify)
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio Manager: Errore configurazione sessione: \(error)")
        }
    }
    
    // MARK: - Configuration
    
    func configure(enabled: Bool, volume: Float) {
        self.isEnabled = enabled
        self.volume = volume
    }
    
    // MARK: - Play Methods
    
    /// Suono click standard per pulsanti
    func playButtonTap() {
        guard isEnabled else { return }
        // System Sound: Key press click (1104)
        playSound(systemID: 1104)
    }
    
    /// Suono scatto fotocamera
    func playCaptureSound() {
        guard isEnabled else { return }
        // System Sound: Shutter (1108)
        playSound(systemID: 1108)
    }
    
    /// Suono "Lock" meccanico per il freeze
    func playFreezeSound() {
        guard isEnabled else { return }
        // System Sound: Lock (1100)
        playSound(systemID: 1100)
    }
    
    /// Suono sblocco
    func playUnfreezeSound() {
        guard isEnabled else { return }
        // System Sound: Unlock (1101) - alternativo a tick
        playSound(systemID: 1101)
    }
    
    /// Tick leggero per cambio zoom
    func playZoomTick() {
        guard isEnabled else { return }
        // System Sound: Wheel tick (1157) o Selection (1123)
        playSound(systemID: 1157)
    }
    
    /// Suono di successo (Salvataggio)
    func playSaveSuccess() {
        guard isEnabled else { return }
        // System Sound: Payment Success / Generic Success (1407 o simile)
        // Usiamo 1001 (Mail Sent) che è riconoscibile e positivo
        playSound(systemID: 1001)
    }
    
    /// Suono di errore
    func playError() {
        guard isEnabled else { return }
        // System Sound: Error (1053)
        playSound(systemID: 1053)
    }
    
    // MARK: - Private Helpers
    
    /// Riproduce un suono di sistema iOS
    private func playSound(systemID: SystemSoundID) {
        // Nota: AudioServicesPlaySystemSound ignora il volume dell'AVAudioPlayer,
        // usa il volume di sistema. Per un controllo volume granulare
        // servirebbero file .wav nel bundle e AVAudioPlayer.
        // Qui usiamo SystemSound per semplicità e leggerezza (MVP).
        AudioServicesPlaySystemSound(systemID)
    }
    
    /// Metodo helper per riprodurre file custom (predisposizione futura)
    private func playCustomFile(named fileName: String, extension ext: String = "wav") {
        guard isEnabled else { return }
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: ext) else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Audio Manager: Errore riproduzione file \(fileName): \(error)")
        }
    }
}
