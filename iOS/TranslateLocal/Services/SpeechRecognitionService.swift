//
//  SpeechRecognitionService.swift
//  TranslateLocal
//
//  Provides speech-to-text transcription using iOS Speech framework
//

import Foundation
import AVFoundation
import Speech

/// Service for recording audio and transcribing speech to text
@MainActor @Observable
class SpeechRecognitionService {
    
    // MARK: - Observable Properties
    
    private(set) var isRecording = false
    private(set) var transcribedText = ""
    private(set) var error: String?
    private(set) var isAuthorized = false
    
    // MARK: - Private Properties
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    
    // MARK: - Initialization
    
    init() {
        // Default to device locale, but can be changed
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
    }
    
    // MARK: - Permission Handling
    
    /// Request microphone and speech recognition permissions
    func requestPermissions() async -> Bool {
        // Request microphone permission
        let microphoneAuthorized = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard microphoneAuthorized else {
            error = "Microphone access denied. Please enable in Settings."
            isAuthorized = false
            return false
        }
        
        // Request speech recognition permission
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        guard speechAuthorized else {
            error = "Speech recognition not authorized. Please enable in Settings."
            isAuthorized = false
            return false
        }
        
        isAuthorized = true
        error = nil
        return true
    }
    
    /// Set the language for speech recognition
    func setLanguage(_ locale: Locale) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }
    
    // MARK: - Recording Control
    
    /// Start recording and transcribing speech
    func startRecording() async throws {
        if !isAuthorized {
            let granted = await requestPermissions()
            if !granted {
                throw SpeechError.notAuthorized
            }
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            error = "Speech recognition not available for this language."
            throw SpeechError.recognizerUnavailable
        }
        
        // Stop any existing recording
        stopRecording()
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw SpeechError.audioEngineError
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.requestCreationFailed
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        
        // Clear previous transcription
        transcribedText = ""
        error = nil
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    // Don't treat cancellation as an error
                    let nsError = error as NSError
                    if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 216 {
                        self.error = error.localizedDescription
                        DebugLogger.translation("Speech recognition error: \(error.localizedDescription)", level: .error)
                    }
                }
            }
        }
        
        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
        DebugLogger.translation("Speech recording started", level: .info)
    }
    
    /// Stop recording and finalize transcription
    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        
        isRecording = false
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        DebugLogger.translation("Speech recording stopped. Transcription: \(transcribedText.prefix(50))...", level: .info)
    }
    
    /// Clear the current transcription
    func clearTranscription() {
        transcribedText = ""
        error = nil
    }
}

// MARK: - Errors

enum SpeechError: LocalizedError {
    case notAuthorized
    case recognizerUnavailable
    case audioEngineError
    case requestCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Microphone or speech recognition not authorized."
        case .recognizerUnavailable:
            return "Speech recognition not available for this language."
        case .audioEngineError:
            return "Failed to initialize audio engine."
        case .requestCreationFailed:
            return "Failed to create speech recognition request."
        }
    }
}
