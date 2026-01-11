//
//  OCRService.swift
//  TranslateLocal
//
//  On-device OCR using Apple's Vision framework
//  Supports real-time text recognition from camera and images
//

import Foundation
import Vision
import UIKit
import Combine

// MARK: - OCR Result Types

/// Represents a recognized text block with position information
struct RecognizedTextBlock: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect  // Normalized coordinates (0-1)
    let language: String?
    
    /// Convert bounding box to view coordinates
    func boundingBox(in size: CGSize) -> CGRect {
        return CGRect(
            x: boundingBox.minX * size.width,
            y: (1 - boundingBox.maxY) * size.height,  // Vision uses bottom-left origin
            width: boundingBox.width * size.width,
            height: boundingBox.height * size.height
        )
    }
}

/// OCR processing result
struct OCRResult {
    let textBlocks: [RecognizedTextBlock]
    let fullText: String
    let detectedLanguages: [String]
    let processingTime: TimeInterval
    
    var isEmpty: Bool {
        return textBlocks.isEmpty
    }
}

/// OCR configuration options
struct OCRConfiguration {
    /// Recognition level (fast or accurate)
    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    
    /// Languages to prioritize (ISO 639-1 codes)
    var recognitionLanguages: [String] = ["en", "ja", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de"]
    
    /// Minimum confidence threshold (0-1)
    var minimumConfidence: Float = 0.5
    
    /// Use language correction
    var usesLanguageCorrection: Bool = true
    
    /// Custom words to recognize
    var customWords: [String] = []
    
    /// Minimum text height as fraction of image height
    var minimumTextHeight: Float = 0.0
    
    static let `default` = OCRConfiguration()
    
    static let fast = OCRConfiguration(
        recognitionLevel: .fast,
        usesLanguageCorrection: false
    )
    
    static let accurate = OCRConfiguration(
        recognitionLevel: .accurate,
        usesLanguageCorrection: true
    )
}

// MARK: - OCR Service

/// Service for performing on-device OCR using Vision framework
@MainActor @Observable
class OCRService {
    
    // MARK: - Observable Properties
    
    private(set) var isProcessing = false
    private(set) var lastResult: OCRResult?
    private(set) var error: OCRError?
    
    // MARK: - Private Properties
    
    private var configuration: OCRConfiguration
    private let processingQueue = DispatchQueue(label: "com.translatelocal.ocr", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(configuration: OCRConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - Public Methods
    
    /// Update OCR configuration
    func updateConfiguration(_ configuration: OCRConfiguration) {
        self.configuration = configuration
    }
    
    /// Recognize text from a UIImage
    func recognizeText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        return try await recognizeText(from: cgImage, orientation: image.imageOrientation.cgImageOrientation)
    }
    
    /// Recognize text from a CGImage
    func recognizeText(from cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) async throws -> OCRResult {
        isProcessing = true
        error = nil
        
        let startTime = Date()
        
        do {
            let result = try await performRecognition(cgImage: cgImage, orientation: orientation)
            let processingTime = Date().timeIntervalSince(startTime)
            
            let ocrResult = OCRResult(
                textBlocks: result.textBlocks,
                fullText: result.fullText,
                detectedLanguages: result.detectedLanguages,
                processingTime: processingTime
            )
            
            self.lastResult = ocrResult
            self.isProcessing = false
            
            return ocrResult
            
        } catch {
            self.isProcessing = false
            let ocrError = error as? OCRError ?? .recognitionFailed(error.localizedDescription)
            self.error = ocrError
            throw ocrError
        }
    }
    
    /// Recognize text from pixel buffer (for camera feed)
    func recognizeText(from pixelBuffer: CVPixelBuffer) async throws -> OCRResult {
        isProcessing = true
        error = nil
        
        let startTime = Date()
        
        do {
            let result = try await performRecognition(pixelBuffer: pixelBuffer)
            let processingTime = Date().timeIntervalSince(startTime)
            
            let ocrResult = OCRResult(
                textBlocks: result.textBlocks,
                fullText: result.fullText,
                detectedLanguages: result.detectedLanguages,
                processingTime: processingTime
            )
            
            self.lastResult = ocrResult
            self.isProcessing = false
            
            return ocrResult
            
        } catch {
            self.isProcessing = false
            let ocrError = error as? OCRError ?? .recognitionFailed(error.localizedDescription)
            self.error = ocrError
            throw ocrError
        }
    }
    
    /// Get supported recognition languages
    static func supportedLanguages() -> [String] {
        do {
            let revision = VNRecognizeTextRequest.currentRevision
            let languages = try VNRecognizeTextRequest.supportedRecognitionLanguages(
                for: .accurate,
                revision: revision
            )
            return languages
        } catch {
            return ["en"]
        }
    }
    
    // MARK: - Private Methods
    
    private struct RecognitionResult {
        let textBlocks: [RecognizedTextBlock]
        let fullText: String
        let detectedLanguages: [String]
    }
    
    private func performRecognition(cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws -> RecognitionResult {
        let config = self.configuration
        return try await withCheckedThrowingContinuation { continuation in
            self.processingQueue.async {
                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: orientation,
                    options: [:]
                )
                
                self.executeRecognition(handler: handler, configuration: config, continuation: continuation)
            }
        }
    }
    
    private func performRecognition(pixelBuffer: CVPixelBuffer) async throws -> RecognitionResult {
        let config = self.configuration
        return try await withCheckedThrowingContinuation { continuation in
            self.processingQueue.async {
                let handler = VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: .up,
                    options: [:]
                )
                
                self.executeRecognition(handler: handler, configuration: config, continuation: continuation)
            }
        }
    }
    
    private func executeRecognition(
        handler: VNImageRequestHandler,
        configuration: OCRConfiguration,
        continuation: CheckedContinuation<RecognitionResult, Error>
    ) {
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                continuation.resume(throwing: OCRError.noTextFound)
                return
            }
            
            let result = self.processObservations(observations, configuration: configuration)
            continuation.resume(returning: result)
        }
        
        // Configure the request
        request.recognitionLevel = configuration.recognitionLevel
        request.recognitionLanguages = configuration.recognitionLanguages
        request.usesLanguageCorrection = configuration.usesLanguageCorrection
        request.minimumTextHeight = configuration.minimumTextHeight
        
        if !configuration.customWords.isEmpty {
            request.customWords = configuration.customWords
        }
        
        // Execute
        do {
            try handler.perform([request])
        } catch {
            continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
        }
    }
    
    private func processObservations(_ observations: [VNRecognizedTextObservation], configuration: OCRConfiguration) -> RecognitionResult {
        var textBlocks: [RecognizedTextBlock] = []
        var fullTextComponents: [String] = []
        var detectedLanguages: Set<String> = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            
            // Filter by confidence
            guard topCandidate.confidence >= configuration.minimumConfidence else {
                continue
            }
            
            let block = RecognizedTextBlock(
                text: topCandidate.string,
                confidence: topCandidate.confidence,
                boundingBox: observation.boundingBox,
                language: detectLanguage(for: topCandidate.string)
            )
            
            textBlocks.append(block)
            fullTextComponents.append(topCandidate.string)
            
            if let language = block.language {
                detectedLanguages.insert(language)
            }
        }
        
        // Sort blocks by position (top to bottom, left to right)
        textBlocks.sort { block1, block2 in
            if abs(block1.boundingBox.maxY - block2.boundingBox.maxY) < 0.02 {
                return block1.boundingBox.minX < block2.boundingBox.minX
            }
            return block1.boundingBox.maxY > block2.boundingBox.maxY
        }
        
        return RecognitionResult(
            textBlocks: textBlocks,
            fullText: fullTextComponents.joined(separator: "\n"),
            detectedLanguages: Array(detectedLanguages)
        )
    }
    
    /// Simple language detection based on character ranges
    private func detectLanguage(for text: String) -> String? {
        let japaneseSet = CharacterSet(charactersIn: "\u{3040}"..."\u{309F}")  // Hiragana
            .union(CharacterSet(charactersIn: "\u{30A0}"..."\u{30FF}"))  // Katakana
        let koreanSet = CharacterSet(charactersIn: "\u{AC00}"..."\u{D7AF}")  // Hangul
        let chineseSet = CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}")  // CJK Unified
        
        let scalars = text.unicodeScalars
        var japaneseCount = 0
        var koreanCount = 0
        var chineseCount = 0
        var latinCount = 0
        
        for scalar in scalars {
            if japaneseSet.contains(scalar) {
                japaneseCount += 1
            } else if koreanSet.contains(scalar) {
                koreanCount += 1
            } else if chineseSet.contains(scalar) {
                chineseCount += 1
            } else if scalar.isASCII && scalar.properties.isAlphabetic {
                latinCount += 1
            }
        }
        
        let maxCount = max(japaneseCount, koreanCount, chineseCount, latinCount)
        
        if maxCount == 0 { return nil }
        
        if japaneseCount == maxCount { return "ja" }
        if koreanCount == maxCount { return "ko" }
        if chineseCount == maxCount { return "zh" }
        if latinCount == maxCount { return "en" }  // Default to English for Latin
        
        return nil
    }
}

// MARK: - Error Types

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case recognitionFailed(String)
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noTextFound:
            return "No text found in image"
        case .recognitionFailed(let reason):
            return "Recognition failed: \(reason)"
        case .serviceUnavailable:
            return "OCR service is unavailable"
        }
    }
}

// MARK: - Extensions

extension UIImage.Orientation {
    var cgImageOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
