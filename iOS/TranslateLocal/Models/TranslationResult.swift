//
//  TranslationResult.swift
//  TranslateLocal
//
//  Data models for translation results and history
//

import Foundation

// MARK: - Translation Result

/// Complete result of a translation operation
struct CompleteTranslationResult: Identifiable, Codable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLanguage: LanguageInfo
    let targetLanguage: LanguageInfo
    let confidence: Double
    let processingTime: TimeInterval
    let modelUsed: String
    let timestamp: Date
    let textBlocks: [TranslatedTextBlock]?
    
    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLanguage: LanguageInfo,
        targetLanguage: LanguageInfo,
        confidence: Double = 1.0,
        processingTime: TimeInterval,
        modelUsed: String,
        timestamp: Date = Date(),
        textBlocks: [TranslatedTextBlock]? = nil
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.confidence = confidence
        self.processingTime = processingTime
        self.modelUsed = modelUsed
        self.timestamp = timestamp
        self.textBlocks = textBlocks
    }
}

// MARK: - Language Info

/// Language information for serialization
struct LanguageInfo: Codable, Hashable {
    let code: String
    let name: String
    let nativeName: String
    
    init(from language: Language) {
        self.code = language.id
        self.name = language.name
        self.nativeName = language.nativeName
    }
    
    init(code: String, name: String, nativeName: String) {
        self.code = code
        self.name = name
        self.nativeName = nativeName
    }
}

// MARK: - Translated Text Block

/// A block of text with its translation and position
struct TranslatedTextBlock: Identifiable, Codable {
    let id: UUID
    let originalText: String
    let translatedText: String
    let boundingBox: CodableCGRect
    let confidence: Float
    
    init(
        id: UUID = UUID(),
        originalText: String,
        translatedText: String,
        boundingBox: CGRect,
        confidence: Float
    ) {
        self.id = id
        self.originalText = originalText
        self.translatedText = translatedText
        self.boundingBox = CodableCGRect(rect: boundingBox)
        self.confidence = confidence
    }
}

// MARK: - Codable CGRect

/// CGRect wrapper for Codable support
struct CodableCGRect: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    init(rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
    
    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Translation Request

/// Request parameters for translation
struct TranslationRequest {
    let text: String
    let sourceLanguage: Language?
    let targetLanguage: Language
    let autoDetect: Bool
    let preferredModel: TranslationModelType?
    
    init(
        text: String,
        sourceLanguage: Language? = nil,
        targetLanguage: Language,
        autoDetect: Bool = true,
        preferredModel: TranslationModelType? = nil
    ) {
        self.text = text
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.autoDetect = autoDetect
        self.preferredModel = preferredModel
    }
}

// MARK: - Translation Statistics

/// Statistics about translation usage
struct TranslationStatistics: Codable {
    var totalTranslations: Int
    var charactersTranslated: Int
    var languagePairCounts: [String: Int]
    var averageProcessingTime: TimeInterval
    var modelUsageCounts: [String: Int]
    var lastUsed: Date
    
    init() {
        self.totalTranslations = 0
        self.charactersTranslated = 0
        self.languagePairCounts = [:]
        self.averageProcessingTime = 0
        self.modelUsageCounts = [:]
        self.lastUsed = Date()
    }
    
    mutating func recordTranslation(
        characterCount: Int,
        languagePair: String,
        processingTime: TimeInterval,
        model: String
    ) {
        totalTranslations += 1
        charactersTranslated += characterCount
        
        languagePairCounts[languagePair, default: 0] += 1
        modelUsageCounts[model, default: 0] += 1
        
        // Update rolling average
        let totalTime = averageProcessingTime * Double(totalTranslations - 1) + processingTime
        averageProcessingTime = totalTime / Double(totalTranslations)
        
        lastUsed = Date()
    }
    
    var mostUsedLanguagePair: String? {
        languagePairCounts.max(by: { $0.value < $1.value })?.key
    }
    
    var mostUsedModel: String? {
        modelUsageCounts.max(by: { $0.value < $1.value })?.key
    }
}
