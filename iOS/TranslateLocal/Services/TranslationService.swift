//
//  TranslationService.swift
//  TranslateLocal
//
//  On-device translation using Core ML models
//  Supports multiple translation backends (Gemma, Opus-MT)
//

import Foundation
import CoreML
import Combine

// MARK: - Translation Result Types

/// Result of a translation operation
struct TranslationResult: Identifiable, Equatable {
    let id = UUID()
    let sourceText: String
    let translatedText: String
    let sourceLanguage: Language
    let targetLanguage: Language
    let confidence: Float
    let processingTime: TimeInterval
    let modelUsed: String
}

/// Supported languages
struct Language: Identifiable, Hashable, Codable {
    let id: String  // ISO 639-1 code
    let name: String
    let nativeName: String
    let isSupported: Bool
    
    static let english = Language(id: "en", name: "English", nativeName: "English", isSupported: true)
    static let japanese = Language(id: "ja", name: "Japanese", nativeName: "日本語", isSupported: true)
    static let chinese = Language(id: "zh", name: "Chinese", nativeName: "中文", isSupported: true)
    static let korean = Language(id: "ko", name: "Korean", nativeName: "한국어", isSupported: true)
    static let spanish = Language(id: "es", name: "Spanish", nativeName: "Español", isSupported: true)
    static let french = Language(id: "fr", name: "French", nativeName: "Français", isSupported: true)
    static let german = Language(id: "de", name: "German", nativeName: "Deutsch", isSupported: true)
    static let russian = Language(id: "ru", name: "Russian", nativeName: "Русский", isSupported: true)
    static let arabic = Language(id: "ar", name: "Arabic", nativeName: "العربية", isSupported: true)
    static let portuguese = Language(id: "pt", name: "Portuguese", nativeName: "Português", isSupported: true)
    
    static let allLanguages: [Language] = [
        .english, .japanese, .chinese, .korean, .spanish,
        .french, .german, .russian, .arabic, .portuguese
    ]
    
    static func from(code: String) -> Language? {
        return allLanguages.first { $0.id == code }
    }
}

/// Translation model types
enum TranslationModelType: String, CaseIterable {
    // Multilingual model (fallback)
    case gemma3n = "Gemma3nE2B"
    
    // ===== MAJOR MODELS: English ↔ Asian Languages =====
    case opusEnJa = "OpusMT_en_ja"
    case opusJaEn = "OpusMT_ja_en"
    case opusEnZh = "OpusMT_en_zh"
    case opusZhEn = "OpusMT_zh_en"
    case opusEnKo = "OpusMT_en_ko"
    case opusKoEn = "OpusMT_ko_en"
    
    // ===== MAJOR MODELS: English ↔ European Languages =====
    case opusEnEs = "OpusMT_en_es"
    case opusEsEn = "OpusMT_es_en"
    case opusEnFr = "OpusMT_en_fr"
    case opusFrEn = "OpusMT_fr_en"
    case opusEnDe = "OpusMT_en_de"
    case opusDeEn = "OpusMT_de_en"
    case opusEnIt = "OpusMT_en_it"
    case opusItEn = "OpusMT_it_en"
    case opusEnPt = "OpusMT_en_pt"
    case opusPtEn = "OpusMT_pt_en"
    case opusEnRu = "OpusMT_en_ru"
    case opusRuEn = "OpusMT_ru_en"
    
    // ===== ADDITIONAL MODELS: Other Language Pairs =====
    case opusEnAr = "OpusMT_en_ar"
    case opusArEn = "OpusMT_ar_en"
    case opusEnNl = "OpusMT_en_nl"
    case opusNlEn = "OpusMT_nl_en"
    case opusEnPl = "OpusMT_en_pl"
    case opusPlEn = "OpusMT_pl_en"
    case opusEnTr = "OpusMT_en_tr"
    case opusTrEn = "OpusMT_tr_en"
    case opusEnVi = "OpusMT_en_vi"
    case opusViEn = "OpusMT_vi_en"
    case opusEnTh = "OpusMT_en_th"
    case opusThEn = "OpusMT_th_en"
    case opusEnHi = "OpusMT_en_hi"
    case opusHiEn = "OpusMT_hi_en"
    
    // ===== NON-ENGLISH PAIRS (Popular) =====
    case opusZhJa = "OpusMT_zh_ja"
    case opusJaZh = "OpusMT_ja_zh"
    case opusFrDe = "OpusMT_fr_de"
    case opusDeFr = "OpusMT_de_fr"
    case opusEsFr = "OpusMT_es_fr"
    case opusFrEs = "OpusMT_fr_es"
    
    var displayName: String {
        switch self {
        case .gemma3n: return "Gemma 3n (Multilingual)"
        // Asian
        case .opusEnJa: return "English → Japanese"
        case .opusJaEn: return "Japanese → English"
        case .opusEnZh: return "English → Chinese"
        case .opusZhEn: return "Chinese → English"
        case .opusEnKo: return "English → Korean"
        case .opusKoEn: return "Korean → English"
        // European
        case .opusEnEs: return "English → Spanish"
        case .opusEsEn: return "Spanish → English"
        case .opusEnFr: return "English → French"
        case .opusFrEn: return "French → English"
        case .opusEnDe: return "English → German"
        case .opusDeEn: return "German → English"
        case .opusEnIt: return "English → Italian"
        case .opusItEn: return "Italian → English"
        case .opusEnPt: return "English → Portuguese"
        case .opusPtEn: return "Portuguese → English"
        case .opusEnRu: return "English → Russian"
        case .opusRuEn: return "Russian → English"
        // Additional
        case .opusEnAr: return "English → Arabic"
        case .opusArEn: return "Arabic → English"
        case .opusEnNl: return "English → Dutch"
        case .opusNlEn: return "Dutch → English"
        case .opusEnPl: return "English → Polish"
        case .opusPlEn: return "Polish → English"
        case .opusEnTr: return "English → Turkish"
        case .opusTrEn: return "Turkish → English"
        case .opusEnVi: return "English → Vietnamese"
        case .opusViEn: return "Vietnamese → English"
        case .opusEnTh: return "English → Thai"
        case .opusThEn: return "Thai → English"
        case .opusEnHi: return "English → Hindi"
        case .opusHiEn: return "Hindi → English"
        // Non-English pairs
        case .opusZhJa: return "Chinese → Japanese"
        case .opusJaZh: return "Japanese → Chinese"
        case .opusFrDe: return "French → German"
        case .opusDeFr: return "German → French"
        case .opusEsFr: return "Spanish → French"
        case .opusFrEs: return "French → Spanish"
        }
    }
    
    var sourceLanguage: Language? {
        switch self {
        case .gemma3n: return nil
        // To English
        case .opusJaEn: return .japanese
        case .opusZhEn: return .chinese
        case .opusKoEn: return .korean
        case .opusEsEn: return .spanish
        case .opusFrEn: return .french
        case .opusDeEn: return .german
        case .opusItEn: return Language(id: "it", name: "Italian", nativeName: "Italiano", isSupported: true)
        case .opusPtEn: return .portuguese
        case .opusRuEn: return .russian
        case .opusArEn: return .arabic
        case .opusNlEn: return Language(id: "nl", name: "Dutch", nativeName: "Nederlands", isSupported: true)
        case .opusPlEn: return Language(id: "pl", name: "Polish", nativeName: "Polski", isSupported: true)
        case .opusTrEn: return Language(id: "tr", name: "Turkish", nativeName: "Türkçe", isSupported: true)
        case .opusViEn: return Language(id: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", isSupported: true)
        case .opusThEn: return Language(id: "th", name: "Thai", nativeName: "ไทย", isSupported: true)
        case .opusHiEn: return Language(id: "hi", name: "Hindi", nativeName: "हिन्दी", isSupported: true)
        // Non-English pairs
        case .opusZhJa: return .chinese
        case .opusJaZh: return .japanese
        case .opusFrDe: return .french
        case .opusDeFr: return .german
        case .opusEsFr: return .spanish
        case .opusFrEs: return .french
        // From English (default)
        default: return .english
        }
    }
    
    var targetLanguage: Language? {
        switch self {
        case .gemma3n: return nil
        // From English
        case .opusEnJa: return .japanese
        case .opusEnZh: return .chinese
        case .opusEnKo: return .korean
        case .opusEnEs: return .spanish
        case .opusEnFr: return .french
        case .opusEnDe: return .german
        case .opusEnIt: return Language(id: "it", name: "Italian", nativeName: "Italiano", isSupported: true)
        case .opusEnPt: return .portuguese
        case .opusEnRu: return .russian
        case .opusEnAr: return .arabic
        case .opusEnNl: return Language(id: "nl", name: "Dutch", nativeName: "Nederlands", isSupported: true)
        case .opusEnPl: return Language(id: "pl", name: "Polish", nativeName: "Polski", isSupported: true)
        case .opusEnTr: return Language(id: "tr", name: "Turkish", nativeName: "Türkçe", isSupported: true)
        case .opusEnVi: return Language(id: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", isSupported: true)
        case .opusEnTh: return Language(id: "th", name: "Thai", nativeName: "ไทย", isSupported: true)
        case .opusEnHi: return Language(id: "hi", name: "Hindi", nativeName: "हिन्दी", isSupported: true)
        // Non-English pairs
        case .opusZhJa: return .japanese
        case .opusJaZh: return .chinese
        case .opusFrDe: return .german
        case .opusDeFr: return .french
        case .opusEsFr: return .french
        case .opusFrEs: return .spanish
        // To English (default)
        default: return .english
        }
    }
    
    /// Category for grouping in UI
    var category: ModelCategory {
        switch self {
        case .gemma3n:
            return .multilingual
        case .opusEnJa, .opusJaEn, .opusEnZh, .opusZhEn, .opusEnKo, .opusKoEn:
            return .majorAsian
        case .opusEnEs, .opusEsEn, .opusEnFr, .opusFrEn, .opusEnDe, .opusDeEn:
            return .majorEuropean
        case .opusZhJa, .opusJaZh, .opusFrDe, .opusDeFr, .opusEsFr, .opusFrEs:
            return .nonEnglish
        default:
            return .additional
        }
    }
    
    /// Estimated model size in MB
    var estimatedSizeMB: Int {
        switch self {
        case .gemma3n: return 800  // Larger multilingual model
        default: return 150  // Opus MT models are ~150MB each
        }
    }
    
    /// HuggingFace model identifier for download
    var huggingFaceId: String {
        switch self {
        case .gemma3n: return "google/gemma-3n-E2B"
        case .opusEnJa: return "Helsinki-NLP/opus-mt-en-ja"
        case .opusJaEn: return "Helsinki-NLP/opus-mt-ja-en"
        case .opusEnZh: return "Helsinki-NLP/opus-mt-en-zh"
        case .opusZhEn: return "Helsinki-NLP/opus-mt-zh-en"
        case .opusEnKo: return "Helsinki-NLP/opus-mt-en-ko"
        case .opusKoEn: return "Helsinki-NLP/opus-mt-ko-en"
        case .opusEnEs: return "Helsinki-NLP/opus-mt-en-es"
        case .opusEsEn: return "Helsinki-NLP/opus-mt-es-en"
        case .opusEnFr: return "Helsinki-NLP/opus-mt-en-fr"
        case .opusFrEn: return "Helsinki-NLP/opus-mt-fr-en"
        case .opusEnDe: return "Helsinki-NLP/opus-mt-en-de"
        case .opusDeEn: return "Helsinki-NLP/opus-mt-de-en"
        case .opusEnIt: return "Helsinki-NLP/opus-mt-en-it"
        case .opusItEn: return "Helsinki-NLP/opus-mt-it-en"
        case .opusEnPt: return "Helsinki-NLP/opus-mt-en-pt"
        case .opusPtEn: return "Helsinki-NLP/opus-mt-pt-en"
        case .opusEnRu: return "Helsinki-NLP/opus-mt-en-ru"
        case .opusRuEn: return "Helsinki-NLP/opus-mt-ru-en"
        case .opusEnAr: return "Helsinki-NLP/opus-mt-en-ar"
        case .opusArEn: return "Helsinki-NLP/opus-mt-ar-en"
        case .opusEnNl: return "Helsinki-NLP/opus-mt-en-nl"
        case .opusNlEn: return "Helsinki-NLP/opus-mt-nl-en"
        case .opusEnPl: return "Helsinki-NLP/opus-mt-en-pl"
        case .opusPlEn: return "Helsinki-NLP/opus-mt-pl-en"
        case .opusEnTr: return "Helsinki-NLP/opus-mt-en-tr"
        case .opusTrEn: return "Helsinki-NLP/opus-mt-tr-en"
        case .opusEnVi: return "Helsinki-NLP/opus-mt-en-vi"
        case .opusViEn: return "Helsinki-NLP/opus-mt-vi-en"
        case .opusEnTh: return "Helsinki-NLP/opus-mt-en-th"
        case .opusThEn: return "Helsinki-NLP/opus-mt-th-en"
        case .opusEnHi: return "Helsinki-NLP/opus-mt-en-hi"
        case .opusHiEn: return "Helsinki-NLP/opus-mt-hi-en"
        case .opusZhJa: return "Helsinki-NLP/opus-mt-zh-ja"
        case .opusJaZh: return "Helsinki-NLP/opus-mt-ja-zh"
        case .opusFrDe: return "Helsinki-NLP/opus-mt-fr-de"
        case .opusDeFr: return "Helsinki-NLP/opus-mt-de-fr"
        case .opusEsFr: return "Helsinki-NLP/opus-mt-es-fr"
        case .opusFrEs: return "Helsinki-NLP/opus-mt-fr-es"
        }
    }
}

/// Model categories for grouping
enum ModelCategory: String, CaseIterable {
    case multilingual = "Multilingual (Any Language)"
    case majorAsian = "Asian Languages"
    case majorEuropean = "European Languages"
    case additional = "Additional Languages"
    case nonEnglish = "Non-English Pairs"
}

// MARK: - Translation Configuration

struct TranslationConfiguration {
    var preferredModel: TranslationModelType = .gemma3n
    var maxInputLength: Int = 512
    var temperature: Float = 0.7
    var topK: Int = 40
    var topP: Float = 0.95
    var useLanguageDetection: Bool = true
    
    static let `default` = TranslationConfiguration()
}

// MARK: - Translation Service

/// Main translation service using on-device ML models
@MainActor @Observable
class TranslationService {

    // MARK: - Timeout Helper

    private func withTimeout<T>(_ seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TranslationError.translationTimeout
            }

            // Wait for first completion
            let result = try await group.next()!
            group.cancelAll()  // Cancel remaining tasks
            return result
        }
    }
    
    // MARK: - Observable Properties
    
    private(set) var isProcessing = false
    private(set) var loadedModels: Set<TranslationModelType> = []
    private(set) var error: TranslationError?
    var configuration = TranslationConfiguration.default
    
    // MARK: - Private Properties
    
    private var models: [TranslationModelType: MLModel] = [:]
    private let modelManager: ModelManager
    private let processingQueue = DispatchQueue(label: "com.translatelocal.translation", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(modelManager: ModelManager = ModelManager.shared) {
        self.modelManager = modelManager
    }
    
    // MARK: - Model Management
    
    /// Load a translation model
    func loadModel(_ type: TranslationModelType) async throws {
        guard !loadedModels.contains(type) else { return }
        
        do {
            let model = try await modelManager.loadModel(type)
            models[type] = model
            loadedModels.insert(type)
        } catch {
            throw TranslationError.modelLoadFailed(type.displayName)
        }
    }
    
    /// Unload a translation model to free memory
    func unloadModel(_ type: TranslationModelType) {
        models.removeValue(forKey: type)
        loadedModels.remove(type)
    }
    
    /// Check if a model is available (bundled or downloaded)
    func isModelAvailable(_ type: TranslationModelType) -> Bool {
        return modelManager.isModelAvailable(type)
    }
    
    // MARK: - Translation
    
    /// Translate text from source to target language
    func translate(
        text: String,
        from sourceLanguage: Language,
        to targetLanguage: Language
    ) async throws -> TranslationResult {
        
        guard !text.isEmpty else {
            throw TranslationError.emptyInput
        }
        
        isProcessing = true
        error = nil
        
        let startTime = Date()
        
        do {
            // Select best model for this language pair
            let modelType = selectModel(from: sourceLanguage, to: targetLanguage)
            
            // Try to load model if available (but don't fail if not - demo mode will handle it)
            if !loadedModels.contains(modelType) && modelManager.isModelAvailable(modelType) {
                try? await loadModel(modelType)
            }
            
            // Perform translation
            let translatedText = try await performTranslation(
                text: text,
                from: sourceLanguage,
                to: targetLanguage,
                using: modelType
            )
            
            let processingTime = Date().timeIntervalSince(startTime)
            
            let result = TranslationResult(
                sourceText: text,
                translatedText: translatedText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                confidence: 0.9,  // Would be calculated from model output
                processingTime: processingTime,
                modelUsed: modelType.displayName
            )
            
            isProcessing = false
            return result
            
        } catch {
            isProcessing = false
            let translationError = error as? TranslationError ?? .translationFailed(error.localizedDescription)
            self.error = translationError
            throw translationError
        }
    }
    
    /// Translate with automatic language detection
    func translateAutoDetect(
        text: String,
        to targetLanguage: Language
    ) async throws -> TranslationResult {
        
        let detectedLanguage = detectLanguage(text)
        return try await translate(text: text, from: detectedLanguage, to: targetLanguage)
    }
    
    // MARK: - Private Methods
    
    private func selectModel(from source: Language, to target: Language) -> TranslationModelType {
        // Check for specialized Opus model for this language pair
        
        // From English
        if source.id == "en" {
            switch target.id {
            case "ja": return .opusEnJa
            case "zh": return .opusEnZh
            case "ko": return .opusEnKo
            case "es": return .opusEnEs
            case "fr": return .opusEnFr
            case "de": return .opusEnDe
            case "it": return .opusEnIt
            case "pt": return .opusEnPt
            case "ru": return .opusEnRu
            case "ar": return .opusEnAr
            case "nl": return .opusEnNl
            case "pl": return .opusEnPl
            case "tr": return .opusEnTr
            case "vi": return .opusEnVi
            case "th": return .opusEnTh
            case "hi": return .opusEnHi
            default: break
            }
        }
        
        // To English
        if target.id == "en" {
            switch source.id {
            case "ja": return .opusJaEn
            case "zh": return .opusZhEn
            case "ko": return .opusKoEn
            case "es": return .opusEsEn
            case "fr": return .opusFrEn
            case "de": return .opusDeEn
            case "it": return .opusItEn
            case "pt": return .opusPtEn
            case "ru": return .opusRuEn
            case "ar": return .opusArEn
            case "nl": return .opusNlEn
            case "pl": return .opusPlEn
            case "tr": return .opusTrEn
            case "vi": return .opusViEn
            case "th": return .opusThEn
            case "hi": return .opusHiEn
            default: break
            }
        }
        
        // Non-English pairs
        if source.id == "zh" && target.id == "ja" { return .opusZhJa }
        if source.id == "ja" && target.id == "zh" { return .opusJaZh }
        if source.id == "fr" && target.id == "de" { return .opusFrDe }
        if source.id == "de" && target.id == "fr" { return .opusDeFr }
        if source.id == "es" && target.id == "fr" { return .opusEsFr }
        if source.id == "fr" && target.id == "es" { return .opusFrEs }
        
        // Fall back to Gemma for unsupported pairs
        return .gemma3n
    }
    
    private func performTranslation(
        text: String,
        from sourceLanguage: Language,
        to targetLanguage: Language,
        using modelType: TranslationModelType
    ) async throws -> String {
        
        // Check if model is loaded - if not, use demo translation
        guard let model = models[modelType] else {
            // Provide demo translation when no models are available
            return try demoTranslation(text: text, from: sourceLanguage, to: targetLanguage)
        }
        
        // This is a placeholder for actual model inference
        // Real implementation would:
        // 1. Tokenize input text
        // 2. Create MLMultiArray input
        // 3. Run model prediction
        // 4. Decode output tokens

        let config = self.configuration
        return try await withTimeout(10.0) {  // 10 second timeout for translation
            try await withCheckedThrowingContinuation { continuation in
                self.processingQueue.async {
                    do {
                        let result = try self.runModelInference(
                            model: model,
                            text: text,
                            sourceLanguage: sourceLanguage,
                            targetLanguage: targetLanguage,
                            modelType: modelType,
                            configuration: config
                        )
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func runModelInference(
        model: MLModel,
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        modelType: TranslationModelType,
        configuration: TranslationConfiguration
    ) throws -> String {
        
        // For Gemma-style models, we construct a prompt
        if modelType == .gemma3n {
            return try runGemmaInference(model: model, text: text, targetLanguage: targetLanguage, configuration: configuration)
        }
        
        // For Opus-MT encoder-decoder models
        return try runOpusInference(model: model, text: text, configuration: configuration)
    }
    
    private func runGemmaInference(
        model: MLModel,
        text: String,
        targetLanguage: Language,
        configuration: TranslationConfiguration
    ) throws -> String {
        // Construct translation prompt
        let prompt = "Translate to \(targetLanguage.name): \(text)"
        
        // Tokenize (simplified - real implementation needs proper tokenizer)
        let tokens = tokenize(prompt)
        
        // Create input array
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)
        for (index, token) in tokens.enumerated() {
            inputArray[index] = NSNumber(value: token)
        }
        
        // Create attention mask
        let attentionMask = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)
        for i in 0..<tokens.count {
            attentionMask[i] = 1
        }
        
        // Run inference
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": inputArray,
            "attention_mask": attentionMask
        ])
        
        let output = try model.prediction(from: input)
        
        // Decode output (simplified)
        guard let logits = output.featureValue(for: "logits")?.multiArrayValue else {
            throw TranslationError.invalidModelOutput
        }
        
        // Greedy decoding (simplified - real implementation would use beam search)
        let outputTokens = greedyDecode(logits: logits, maxLength: configuration.maxInputLength)
        let translatedText = detokenize(outputTokens)
        
        return translatedText
    }
    
    private func runOpusInference(
        model: MLModel,
        text: String,
        configuration: TranslationConfiguration
    ) throws -> String {
        // Tokenize
        let tokens = tokenize(text)
        
        // Create encoder input
        let inputArray = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)
        for (index, token) in tokens.enumerated() {
            inputArray[index] = NSNumber(value: token)
        }
        
        // Create attention mask
        let attentionMask = try MLMultiArray(shape: [1, NSNumber(value: tokens.count)], dataType: .int32)
        for i in 0..<tokens.count {
            attentionMask[i] = 1
        }
        
        // Create initial decoder input (start token)
        let decoderInput = try MLMultiArray(shape: [1, 1], dataType: .int32)
        decoderInput[0] = 0  // Decoder start token ID
        
        // Run inference
        let input = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": inputArray,
            "attention_mask": attentionMask,
            "decoder_input_ids": decoderInput
        ])
        
        let output = try model.prediction(from: input)
        
        // Decode output
        guard let logits = output.featureValue(for: "logits")?.multiArrayValue else {
            throw TranslationError.invalidModelOutput
        }
        
        let outputTokens = greedyDecode(logits: logits, maxLength: configuration.maxInputLength)
        return detokenize(outputTokens)
    }
    
    // MARK: - Tokenization (Placeholder implementations)
    
    private func tokenize(_ text: String) -> [Int32] {
        // Placeholder - real implementation would use SentencePiece or similar
        // This is a very simplified tokenization for demonstration
        var tokens: [Int32] = []
        
        for char in text {
            tokens.append(Int32(char.asciiValue ?? 0))
        }
        
        return tokens
    }
    
    private func detokenize(_ tokens: [Int32]) -> String {
        // Placeholder - real implementation would use proper vocabulary lookup
        var result = ""
        
        for token in tokens {
            if token > 0 && token < 128 {
                result.append(Character(UnicodeScalar(UInt8(token))))
            }
        }
        
        return result
    }
    
    private func greedyDecode(logits: MLMultiArray, maxLength: Int) -> [Int32] {
        // Simplified greedy decoding
        var outputTokens: [Int32] = []
        let vocabSize = logits.shape[2].intValue
        
        for step in 0..<min(maxLength, logits.shape[1].intValue) {
            var maxProb: Float = -Float.infinity
            var maxToken: Int32 = 0
            
            for v in 0..<vocabSize {
                let index = [0, step, v] as [NSNumber]
                let prob = logits[index].floatValue
                if prob > maxProb {
                    maxProb = prob
                    maxToken = Int32(v)
                }
            }
            
            // Stop at EOS token (typically 1 or 2)
            if maxToken == 1 || maxToken == 2 {
                break
            }
            
            outputTokens.append(maxToken)
        }
        
        return outputTokens
    }
    
    // MARK: - Demo Translation (Fallback when no models available)

    /// Provides basic demo message when no models are available
    private func demoTranslation(text: String, from source: Language, to target: Language) throws -> String {
        return "[Demo Mode] No AI models installed. Download models from the Translate tab to enable real translation.\n\nOriginal: \(text)"
    }
    
    // MARK: - Language Detection
    
    private func detectLanguage(_ text: String) -> Language {
        // Simple character-based detection
        let japaneseSet = CharacterSet(charactersIn: "\u{3040}"..."\u{309F}")
            .union(CharacterSet(charactersIn: "\u{30A0}"..."\u{30FF}"))
        let koreanSet = CharacterSet(charactersIn: "\u{AC00}"..."\u{D7AF}")
        let chineseSet = CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}")
        let arabicSet = CharacterSet(charactersIn: "\u{0600}"..."\u{06FF}")
        let cyrillicSet = CharacterSet(charactersIn: "\u{0400}"..."\u{04FF}")
        
        let scalars = text.unicodeScalars
        var counts: [String: Int] = [:]
        
        for scalar in scalars {
            if japaneseSet.contains(scalar) {
                counts["ja", default: 0] += 1
            } else if koreanSet.contains(scalar) {
                counts["ko", default: 0] += 1
            } else if chineseSet.contains(scalar) {
                counts["zh", default: 0] += 1
            } else if arabicSet.contains(scalar) {
                counts["ar", default: 0] += 1
            } else if cyrillicSet.contains(scalar) {
                counts["ru", default: 0] += 1
            }
        }
        
        if let (code, _) = counts.max(by: { $0.value < $1.value }) {
            return Language.from(code: code) ?? .english
        }
        
        return .english
    }
}

// MARK: - Error Types

enum TranslationError: LocalizedError {
    case emptyInput
    case modelNotLoaded(String)
    case modelLoadFailed(String)
    case translationFailed(String)
    case translationTimeout
    case unsupportedLanguagePair
    case invalidModelOutput

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Input text is empty"
        case .modelNotLoaded(let name):
            return "Model '\(name)' is not loaded"
        case .modelLoadFailed(let name):
            return "Failed to load model '\(name)'"
        case .translationFailed(let reason):
            return "Translation failed: \(reason)"
        case .translationTimeout:
            return "Translation timed out. Please try again."
        case .unsupportedLanguagePair:
            return "This language pair is not supported"
        case .invalidModelOutput:
            return "Invalid output from translation model"
        }
    }
}
