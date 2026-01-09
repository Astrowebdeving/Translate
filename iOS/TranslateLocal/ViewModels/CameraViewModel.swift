//
//  CameraViewModel.swift
//  TranslateLocal
//
//  View model for camera-based translation
//

import Foundation
import AVFoundation
import Combine
import Vision

@MainActor
class CameraViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isActive = false
    @Published var isPaused = false
    @Published var flashEnabled = false
    @Published var recognizedBlocks: [RecognizedTextBlock] = []
    @Published var translatedTexts: [UUID: String] = [:]
    @Published var isTranslating = false
    @Published var error: String?
    @Published var fps: Double = 0
    
    // MARK: - Dependencies
    
    private let ocrService: OCRService
    private let translationService: TranslationService
    
    // MARK: - Private Properties
    
    private var lastProcessedTime: Date = Date()
    private var frameCount = 0
    private var cancellables = Set<AnyCancellable>()
    
    // Throttling
    private let processingInterval: TimeInterval = 0.3  // Process every 300ms
    private var lastOCRTime: Date = .distantPast
    
    // MARK: - Initialization
    
    init(ocrService: OCRService, translationService: TranslationService) {
        self.ocrService = ocrService
        self.translationService = translationService
    }
    
    // MARK: - Public Methods
    
    func startCamera() {
        isActive = true
        lastProcessedTime = Date()
        frameCount = 0
    }
    
    func stopCamera() {
        isActive = false
    }
    
    func togglePause() {
        isPaused.toggle()
    }
    
    func toggleFlash() {
        flashEnabled.toggle()
    }
    
    /// Process a frame from the camera
    func processFrame(_ pixelBuffer: CVPixelBuffer, sourceLanguage: Language, targetLanguage: Language) async {
        // Throttle processing
        let now = Date()
        guard now.timeIntervalSince(lastOCRTime) >= processingInterval else { return }
        guard !isPaused && !ocrService.isProcessing else { return }
        
        lastOCRTime = now
        
        // Update FPS counter
        frameCount += 1
        let elapsed = now.timeIntervalSince(lastProcessedTime)
        if elapsed >= 1.0 {
            fps = Double(frameCount) / elapsed
            frameCount = 0
            lastProcessedTime = now
        }
        
        do {
            // Perform OCR
            let result = try await ocrService.recognizeText(from: pixelBuffer)
            
            // Update recognized blocks
            self.recognizedBlocks = result.textBlocks
            
            // Translate new blocks
            await translateNewBlocks(result.textBlocks, from: sourceLanguage, to: targetLanguage)
            
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    /// Clear all translations
    func clearTranslations() {
        recognizedBlocks = []
        translatedTexts = [:]
    }
    
    // MARK: - Private Methods
    
    private func translateNewBlocks(_ blocks: [RecognizedTextBlock], from source: Language, to target: Language) async {
        // Find blocks that haven't been translated yet
        let newBlocks = blocks.filter { block in
            translatedTexts[block.id] == nil && !block.text.isEmpty
        }
        
        guard !newBlocks.isEmpty else { return }
        
        isTranslating = true
        
        // Translate in parallel with limited concurrency
        await withTaskGroup(of: (UUID, String?).self) { group in
            for block in newBlocks.prefix(3) {  // Limit concurrent translations
                group.addTask {
                    do {
                        let result = try await self.translationService.translate(
                            text: block.text,
                            from: source,
                            to: target
                        )
                        return (block.id, result.translatedText)
                    } catch {
                        return (block.id, nil)
                    }
                }
            }
            
            for await (id, translation) in group {
                if let translation = translation {
                    self.translatedTexts[id] = translation
                }
            }
        }
        
        isTranslating = false
    }
    
    // MARK: - Statistics
    
    var activeBlockCount: Int {
        recognizedBlocks.count
    }
    
    var translatedBlockCount: Int {
        translatedTexts.count
    }
    
    var pendingTranslations: Int {
        recognizedBlocks.count - translatedTexts.count
    }
}

// MARK: - Camera Permission Helper

enum CameraPermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
}

@MainActor
class CameraPermissionManager: ObservableObject {
    @Published var status: CameraPermissionStatus = .notDetermined
    
    init() {
        checkStatus()
    }
    
    func checkStatus() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            status = .notDetermined
        case .authorized:
            status = .authorized
        case .denied:
            status = .denied
        case .restricted:
            status = .restricted
        @unknown default:
            status = .denied
        }
    }
    
    func requestPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            status = granted ? .authorized : .denied
        }
        return granted
    }
}
