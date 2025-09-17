import Foundation
import AVFoundation
import Speech

class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var isRecording = false
    @Published var recordingText = ""
    @Published var hasPermission = false
    
    // Callback for when recording finishes
    var onRecordingFinished: ((String) -> Void)?
    
    // MARK: - Private Properties
    private let synthesizer = AVSpeechSynthesizer()
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    override init() {
        super.init()
        
        // Initialize synthesizer safely
        synthesizer.delegate = self
        print("✅ SpeechManager initialized (TTS + STT)")
        
        // Log available voices for debugging
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.logAvailableVoices()
        }
        
        // Request permissions with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.requestPermissions()
        }
    }
    
    // MARK: - Permission Handling
    private func requestPermissions() {
        // Check if speech recognizer is available
        guard let _ = speechRecognizer, speechRecognizer?.isAvailable == true else {
            print("❌ Speech recognizer not available")
            hasPermission = false
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.requestMicrophonePermission()
                case .denied, .restricted, .notDetermined:
                    self?.hasPermission = false
                    print("❌ Speech recognition permission denied")
                @unknown default:
                    self?.hasPermission = false
                }
            }
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
                if !granted {
                    print("❌ Microphone permission denied")
                } else {
                    print("✅ Microphone permission granted")
                }
            }
        }
    }
    
    // MARK: - Speech-to-Text
    func startRecording() {
        guard hasPermission else {
            print("❌ No permission for speech recognition")
            return
        }
        
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isPlaying = false
        }
        
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            isRecording = false
            print("🛑 STT: Audio engine stopped, recording ended")
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ STT: Audio session configured for recording")
        } catch {
            print("❌ STT: Audio session setup failed: \(error)")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
        }
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            var isFinal = false
            
            if let result = result {
                self.recordingText = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                self.isRecording = false
                print("🛑 STT: Recognition task ended. Final: \(isFinal), Error: \(error?.localizedDescription ?? "None")")
                
                // If recording stopped and text is available, trigger callback
                if isFinal && !self.recordingText.isEmpty {
                    print("🎤 Final recorded text: \(self.recordingText)")
                    self.onRecordingFinished?(self.recordingText)
                }
            }
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            recordingText = ""
            print("✅ STT: Audio engine started, recording initiated")
        } catch {
            print("❌ STT: Audio engine couldn't start: \(error)")
            isRecording = false
        }
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            isRecording = false
            print("🛑 STT: Recording stopped by user")
            
            // Call the callback with the recorded text
            if !recordingText.isEmpty {
                onRecordingFinished?(recordingText)
            }
        }
        // Reset audio session to default
        resetAudioSession()
    }
    
    // MARK: - Voice Selection
    private func selectBestVoice() -> AVSpeechSynthesisVoice? {
        // List of preferred enhanced voices in order of preference
        let preferredVoices = [
            "com.apple.voice.enhanced.en-US.Samantha",      // Enhanced Samantha (very natural)
            "com.apple.voice.enhanced.en-US.Alex",          // Enhanced Alex (natural male)
            "com.apple.voice.enhanced.en-US.Victoria",      // Enhanced Victoria (natural female)
            "com.apple.voice.enhanced.en-US.Daniel",        // Enhanced Daniel (natural male)
            "com.apple.voice.enhanced.en-US.Zoe",           // Enhanced Zoe (natural female)
            "com.apple.voice.compact.en-US.Samantha",       // Compact Samantha (fallback)
            "com.apple.voice.compact.en-US.Alex",           // Compact Alex (fallback)
        ]
        
        // Try to find the first available enhanced voice
        for voiceIdentifier in preferredVoices {
            if let voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
                print("✅ TTS: Using enhanced voice: \(voice.name)")
                return voice
            }
        }
        
        // Fallback to any enhanced voice for English
        if let enhancedVoice = AVSpeechSynthesisVoice.speechVoices().first(where: { 
            $0.language.hasPrefix("en") && $0.quality == .enhanced 
        }) {
            print("✅ TTS: Using available enhanced voice: \(enhancedVoice.name)")
            return enhancedVoice
        }
        
        // Final fallback to default voice
        let defaultVoice = AVSpeechSynthesisVoice(language: "en-US")
        print("⚠️ TTS: Using default voice: \(defaultVoice?.name ?? "Unknown")")
        return defaultVoice
    }
    
    // MARK: - Voice Information
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
    }
    
    func getCurrentVoiceInfo() -> String {
        if let currentVoice = selectBestVoice() {
            return "\(currentVoice.name) (\(currentVoice.quality == .enhanced ? "Enhanced" : "Default"))"
        }
        return "Unknown Voice"
    }
    
    private func logAvailableVoices() {
        let voices = getAvailableVoices()
        print("🎤 Available English voices:")
        for voice in voices {
            let quality = voice.quality == .enhanced ? "Enhanced" : "Default"
            print("  - \(voice.name) (\(quality)) - \(voice.identifier)")
        }
        print("🎤 Selected voice: \(getCurrentVoiceInfo())")
    }
    
    // MARK: - Text-to-Speech
    func speak(_ text: String) {
        guard !text.isEmpty else { 
            print("⚠️ TTS: Empty text provided")
            return 
        }
        
        print("🔊 TTS: Attempting to speak: \(text.prefix(50))...")
        
        // Stop any current speech
        if synthesizer.isSpeaking {
            print("🛑 TTS: Stopping current speech")
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        
        // Use enhanced voices for more natural sound
        utterance.voice = selectBestVoice()
        utterance.rate = 0.52  // Slightly faster for more natural flow
        utterance.pitchMultiplier = 1.1  // Slightly higher pitch for more natural sound
        utterance.volume = 0.9  // Higher volume for better clarity
        
        // Configure audio session for playback with better error handling
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ TTS: Audio session configured successfully")
        } catch {
            print("❌ TTS: Audio session setup failed: \(error)")
            // Continue anyway - TTS might still work
        }
        
        // Start speaking
        synthesizer.speak(utterance)
        isPlaying = true
        print("🔊 TTS: Started speaking")
    }
    
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isPlaying = false
            print("🛑 TTS: Speaking stopped by user")
        }
        // Reset audio session to default
        resetAudioSession()
    }
    
    private func resetAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ Audio session reset to ambient")
        } catch {
            print("❌ Failed to reset audio session: \(error)")
        }
    }
    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            print("✅ TTS: Finished speaking")
            self?.resetAudioSession()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            print("🛑 TTS: Speaking cancelled")
            self?.resetAudioSession()
        }
    }
}
