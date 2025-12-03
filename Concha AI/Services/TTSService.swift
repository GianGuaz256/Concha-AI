//
//  TTSService.swift
//  Concha AI
//
//  Text-to-speech wrapper using AVSpeechSynthesizer
//

import Foundation
import AVFoundation

@MainActor
@Observable
class TTSService: NSObject {
    static let shared = TTSService()
    
    private let synthesizer = AVSpeechSynthesizer()
    var isSpeaking: Bool = false
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "ttsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "ttsEnabled") }
    }
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func speak(_ text: String) {
        guard isEnabled else { return }
        
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Use a natural sounding voice if available
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    func toggle() {
        isEnabled.toggle()
        if !isEnabled {
            stop()
        }
    }
}

extension TTSService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

