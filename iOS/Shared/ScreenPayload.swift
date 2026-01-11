//
//  ScreenPayload.swift
//  TranslateLocal
//
//  Data models for screen capture and translation communication
//  Shared between main app and Broadcast Upload Extension
//

import Foundation
import CoreGraphics

// MARK: - Screen Payload (Extension → App)

/// Payload containing OCR results from the Broadcast Extension
/// Written by the extension, read by the main app
struct ScreenPayload: Codable, Equatable {
    /// Timestamp when this payload was created
    let timestamp: Date
    
    /// Unique identifier for this payload
    let id: UUID
    
    /// Extracted text blocks from the screen
    let textBlocks: [ScreenTextBlock]
    
    /// Full concatenated text from all blocks
    let fullText: String
    
    /// Detected languages in the text
    let detectedLanguages: [String]
    
    /// Screen dimensions at time of capture
    let screenSize: CGSize
    
    /// Whether this is from a new frame or updated
    let isNewFrame: Bool
    
    init(
        textBlocks: [ScreenTextBlock],
        fullText: String,
        detectedLanguages: [String],
        screenSize: CGSize,
        isNewFrame: Bool = true
    ) {
        self.timestamp = Date()
        self.id = UUID()
        self.textBlocks = textBlocks
        self.fullText = fullText
        self.detectedLanguages = detectedLanguages
        self.screenSize = screenSize
        self.isNewFrame = isNewFrame
    }
}

/// Individual text block recognized from screen
struct ScreenTextBlock: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let confidence: Float
    let boundingBox: CGRect  // Normalized coordinates (0-1)
    let language: String?
    
    init(text: String, confidence: Float, boundingBox: CGRect, language: String? = nil) {
        self.id = UUID()
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.language = language
    }
}

// MARK: - Translation Result (App → Extension/PiP)

/// Translation result to be displayed in PiP window
struct ScreenTranslationResult: Codable, Equatable {
    /// Timestamp of this translation
    let timestamp: Date
    
    /// ID of the original payload this translates
    let payloadId: UUID
    
    /// Translated text blocks (keyed by original block ID)
    let translations: [String: TranslatedBlock]
    
    /// Overall status
    let status: TranslationStatus
    
    /// Error message if any
    let errorMessage: String?
    
    init(
        payloadId: UUID,
        translations: [String: TranslatedBlock],
        status: TranslationStatus,
        errorMessage: String? = nil
    ) {
        self.timestamp = Date()
        self.payloadId = payloadId
        self.translations = translations
        self.status = status
        self.errorMessage = errorMessage
    }
}

/// A translated text block
struct TranslatedBlock: Codable, Equatable {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let confidence: Float
}

/// Status of translation
enum TranslationStatus: String, Codable {
    case idle
    case processing
    case completed
    case error
    case paused
}

// MARK: - Screen Mode Settings

/// Shared settings for screen translation mode
struct ScreenModeSettings: Codable {
    var isActive: Bool
    var sourceLanguageCode: String
    var targetLanguageCode: String
    var processingInterval: TimeInterval  // Seconds between OCR processing
    var showOriginalText: Bool
    var overlayOpacity: Float
    var fontSize: Float
    var lastUpdated: Date
    
    static let `default` = ScreenModeSettings(
        isActive: false,
        sourceLanguageCode: "en",
        targetLanguageCode: "ja",
        processingInterval: 1.0,
        showOriginalText: false,
        overlayOpacity: 0.9,
        fontSize: 16,
        lastUpdated: Date()
    )
    
    /// Save to shared container
    func save() throws {
        try AppGroupConstants.save(self, to: AppGroupConstants.settingsFileName)
    }
    
    /// Load from shared container
    static func load() -> ScreenModeSettings {
        do {
            return try AppGroupConstants.load(ScreenModeSettings.self, from: AppGroupConstants.settingsFileName)
        } catch {
            return .default
        }
    }
}

// MARK: - Broadcast State

/// State of the broadcast extension
enum BroadcastState: String, Codable {
    case inactive
    case starting
    case active
    case stopping
    case error
}

/// Broadcast status shared between app and extension
struct BroadcastStatus: Codable {
    let state: BroadcastState
    let timestamp: Date
    let frameCount: Int
    let errorMessage: String?
    
    init(state: BroadcastState, frameCount: Int = 0, errorMessage: String? = nil) {
        self.state = state
        self.timestamp = Date()
        self.frameCount = frameCount
        self.errorMessage = errorMessage
    }
}

// MARK: - CGRect Codable Extension

extension CGRect: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(x: x, y: y, width: width, height: height)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(origin.x, forKey: .x)
        try container.encode(origin.y, forKey: .y)
        try container.encode(size.width, forKey: .width)
        try container.encode(size.height, forKey: .height)
    }
}

// MARK: - CGSize Codable Extension

extension CGSize: Codable {
    enum CodingKeys: String, CodingKey {
        case width, height
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}
