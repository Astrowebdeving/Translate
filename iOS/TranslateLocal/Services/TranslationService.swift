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
    
    // MARK: - Private Properties
    
    private var models: [TranslationModelType: MLModel] = [:]
    private var decoders: [TranslationModelType: MLModel] = [:] // Store decoders separately
    private var tokenizers: [TranslationModelType: ModelTokenizer] = [:] // Store tokenizers
    private let modelManager: ModelManager
    private let processingQueue = DispatchQueue(label: "com.translatelocal.translation", qos: .userInitiated)
    
    // MARK: - Initialization
    
    init(modelManager: ModelManager = ModelManager.shared) {
        self.modelManager = modelManager
    }
    
    // MARK: - Model Management
    
    /// Load a translation model
    func loadModel(_ type: TranslationModelType) async throws {
        DebugLogger.model("loadModel called for \(type.rawValue)", level: .debug)
        guard !loadedModels.contains(type) else { 
            DebugLogger.model("Model \(type.rawValue) already loaded", level: .debug)
            return 
        }
        
        do {
            // Load encoder (standard model)
            let model = try await modelManager.loadModel(type)
            models[type] = model
            
            // For Opus-MT models, also load the decoder and tokenizer
            // These types start with "OpusMT_"
            if type.rawValue.starts(with: "OpusMT_") {
                // Load decoder
                let decoder = try await modelManager.loadDecoder(type)
                decoders[type] = decoder
                DebugLogger.model("Loaded decoder for \(type.displayName)", level: .info)
                
                // Load tokenizer
                if let modelURL = modelManager.getModelURL(for: type) {
                    // modelURL is .../OpusMT_zh_en_encoder.mlmodelc
                    // Parent dir contains vocab.json
                    let parentURL = modelURL.deletingLastPathComponent()
                    let tokenizer = try ModelTokenizer(directory: parentURL)
                    tokenizers[type] = tokenizer
                    DebugLogger.model("Loaded tokenizer for \(type.displayName)", level: .info)
                }
            }
            
            loadedModels.insert(type)
        } catch {
            // Clean up if partial load failed
            models.removeValue(forKey: type)
            decoders.removeValue(forKey: type)
            tokenizers.removeValue(forKey: type)
            throw TranslationError.modelLoadFailed(type.displayName)
        }
    }
    
    /// Unload a translation model to free memory
    func unloadModel(_ type: TranslationModelType) {
        models.removeValue(forKey: type)
        decoders.removeValue(forKey: type)
        tokenizers.removeValue(forKey: type)
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
        DebugLogger.translation("translate() called: '\(text.prefix(30))' from \(sourceLanguage.id) to \(targetLanguage.id)", level: .info)
        
        guard !text.isEmpty else {
            DebugLogger.translation("Empty input - throwing error", level: .warning)
            throw TranslationError.emptyInput
        }
        
        isProcessing = true
        error = nil
        
        let startTime = Date()
        
        do {
            // Select best model for this language pair
            let modelType = selectModel(from: sourceLanguage, to: targetLanguage)
            DebugLogger.translation("Selected model: \(modelType.rawValue)", level: .debug)
            
            // Check model availability via filesystem (ModelManager.availableModels can be stale until it rescans)
            let isAvailable = modelManager.getModelURL(for: modelType) != nil
            let isLoaded = loadedModels.contains(modelType)
            DebugLogger.translation("Model \(modelType.rawValue): available=\(isAvailable), loaded=\(isLoaded)", level: .debug)
            
            // If the model is available on-device, it should be loadable.
            // Failing to load should be surfaced (otherwise we can end up with silent empty output).
            if !isLoaded && isAvailable {
                DebugLogger.translation("Attempting to load model \(modelType.rawValue)", level: .debug)
                try await loadModel(modelType)
                DebugLogger.translation("Model loaded successfully", level: .info)
            }
            
            DebugLogger.translation("Calling performTranslation", level: .debug)
            // Perform translation
            let translatedTextRaw = try await performTranslation(
                text: text,
                from: sourceLanguage,
                to: targetLanguage,
                using: modelType
            )
            
            let translatedText = translatedTextRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if translatedText.isEmpty {
                DebugLogger.translation("Translation produced empty output (model=\(modelType.rawValue))", level: .error)
                throw TranslationError.translationFailed("Model returned empty output. Check tokenizer/model files for \(modelType.rawValue).")
            }
            
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
        DebugLogger.translation("performTranslation called with model \(modelType.rawValue)", level: .debug)
        
        
        // NEW: Use GemmaService via MLX when available for .gemma3n model type
        if modelType == .gemma3n && GemmaService.shared.isLoaded {
            DebugLogger.translation("Using GemmaService (MLX) for translation", level: .info)
            return try await GemmaService.shared.translate(
                text: text,
                from: sourceLanguage.name,
                to: targetLanguage.name
            )
        }
        
        // Try to load Gemma if it's the selected model and not yet loaded
        if modelType == .gemma3n && MLXModelManager.shared.isGemmaReady && !GemmaService.shared.isLoaded {
            do {
                try await GemmaService.shared.loadModel()
                DebugLogger.translation("Loaded GemmaService, retrying with MLX", level: .info)
                return try await GemmaService.shared.translate(
                    text: text,
                    from: sourceLanguage.name,
                    to: targetLanguage.name
                )
            } catch {
                DebugLogger.translation("Failed to load GemmaService: \(error.localizedDescription)", level: .warning)
                // Fall through to demo translation
            }
        }
        
        // Check if CoreML model is loaded - if not, use demo translation
        DebugLogger.translation("Checking models dict for \\(modelType.rawValue). Keys: \\(Array(models.keys).map { $0.rawValue })", level: .debug)
        guard let model = models[modelType] else {
            DebugLogger.translation("Model \\(modelType.rawValue) NOT in models dict - falling back to demo", level: .warning)
            // Provide demo translation when no models are available
            return try demoTranslation(text: text, from: sourceLanguage, to: targetLanguage)
        }
        DebugLogger.translation("Model \\(modelType.rawValue) found in dict - proceeding with CoreML inference", level: .debug)
        
        // CoreML-based translation (for Opus-MT models)
        let config = self.configuration
        #if targetEnvironment(simulator)
        let timeoutSeconds: TimeInterval = 30.0
        #else
        let timeoutSeconds: TimeInterval = 10.0
        #endif
        
        return try await withTimeout(timeoutSeconds) {  // Simulator can be much slower
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
        // Find associated tokenizer and decoder
        // We look up based on the model instance (associated with the key in our dict)
        guard let modelType = models.first(where: { $0.value === model })?.key,
              let tokenizer = tokenizers[modelType],
              let decoder = decoders[modelType] else {
            // Need to verify why dependencies are missing
            if tokenizers.isEmpty {
                DebugLogger.translation("No tokenizers available. Ensure model loaded correctly.", level: .error)
            }
            throw TranslationError.modelNotLoaded("Tokenizer/Decoder")
        }
        
        // 1. Tokenize
        let inputTokens = tokenizer.tokenize(text)
        DebugLogger.translation("Input Tokens: \(inputTokens)", level: .debug)
        if inputTokens.isEmpty {
            DebugLogger.translation("Tokenizer returned 0 tokens for non-empty input", level: .error)
            throw TranslationError.translationFailed("Tokenizer returned 0 tokens. This usually means vocab/tokenizer files don't match the model.")
        }
        
        // Quick sanity: show first few vocab pieces for input (helps diagnose vocab mismatch)
        if inputTokens.count > 0 {
            let preview = inputTokens.prefix(12).map { tid -> String in
                let id = Int(tid)
                // Access internal mapping via detokenize trick is expensive; instead just show IDs here.
                // (We log IDs since vocab JSON is huge; IDs are still actionable.)
                return String(id)
            }.joined(separator: ",")
            DebugLogger.translation("Input token id preview: [\(preview)]", level: .debug)
        }
        
        let batchSize = 1
        let seqLen = inputTokens.count
        let maxLen = tokenizer.config.max_length
        let padToken = Int32(tokenizer.config.pad_token_id)
        
        // 2. Encoder Inference
        // Create encoder inputs
        // NOTE: These CoreML models were traced with max_length=512. Even if they declare RangeDim,
        // Torch tracing can bake in shape assumptions. We pad to fixed length to keep encoder/decoder stable.
        let encoderInputIds = try MLMultiArray(shape: [NSNumber(value: batchSize), NSNumber(value: maxLen)], dataType: .int32)
        let attentionMaskMultiArray = try MLMultiArray(shape: [NSNumber(value: batchSize), NSNumber(value: maxLen)], dataType: .int32)
        
        // Initialize with PAD + 0 mask
        for i in 0..<maxLen {
            encoderInputIds[i] = NSNumber(value: padToken)
            attentionMaskMultiArray[i] = 0
        }
        
        // Fill prefix with real tokens
        let usedLen = min(seqLen, maxLen)
        for i in 0..<usedLen {
            encoderInputIds[i] = NSNumber(value: inputTokens[i])
            attentionMaskMultiArray[i] = 1
        }
        
        // Try dictionary inputs - check model description if possible
        // Standard HuggingFace export names: input_ids, attention_mask
        let encoderInput = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": encoderInputIds,
            "attention_mask": attentionMaskMultiArray
        ])
        
        // Run Encoder
        DebugLogger.translation("Running Encoder for \(modelType.rawValue)", level: .debug)
        let encoderOutput = try model.prediction(from: encoderInput)
        DebugLogger.translation("Encoder Output Features: \(encoderOutput.featureNames)", level: .debug)
        
        // Extract encoder hidden state (usually 'last_hidden_state' or 'var_...' or 'linear_...')
        // We iterate features to find the large tensor, likely the last hidden state
        let hiddenStateName = encoderOutput.featureNames.first { $0.contains("hidden_state") || $0.contains("encoder_hidden") }
            ?? encoderOutput.featureNames.first(where: { name in
                guard let value = encoderOutput.featureValue(for: name)?.multiArrayValue else { return false }
                return value.shape.count == 3 // [batch, seq, hidden_dim]
            }) 
            ?? "encoder_hidden_states"
            
        guard let encoderHiddenStateRaw = encoderOutput.featureValue(for: hiddenStateName)?.multiArrayValue else {
            DebugLogger.translation("Could not find encoder hidden states in output: \(encoderOutput.featureNames)", level: .error)
            throw TranslationError.invalidModelOutput
        }
        
        DebugLogger.translation("Encoder Hidden Raw: Shape \(encoderHiddenStateRaw.shape), Type \(encoderHiddenStateRaw.dataType.rawValue)", level: .debug)
        
        // Ensure encoder hidden state is FP32 (Decoder expects FP32)
        // Some encoders output FP16 (Float16)
        let encoderHiddenState = try convertToFP32(encoderHiddenStateRaw)
        DebugLogger.translation("Encoder Hidden Converted: Shape \(encoderHiddenState.shape), Type \(encoderHiddenState.dataType.rawValue)", level: .debug)
        
        // 3. Decoder Loop (Greedy Search)
        // Use correct start token from config
        let startToken = Int32(tokenizer.config.decoder_start_token_id)
        let eosToken = Int32(tokenizer.config.eos_token_id)
        
        var outputTokens: [Int32] = [startToken] 
        
        DebugLogger.translation("Starting Decoder Loop. Start: \(startToken), EOS: \(eosToken)", level: .debug)
        
        // Decoder output length cap: keep UI responsive.
        #if targetEnvironment(simulator)
        let maxDecodeSteps = min(48, tokenizer.config.max_length)
        let decodeTimeBudgetSeconds: TimeInterval = 6.0
        #else
        let maxDecodeSteps = min(128, tokenizer.config.max_length)
        let decodeTimeBudgetSeconds: TimeInterval = 12.0
        #endif
        
        let decodeStart = Date()
        var bigramCounts: [UInt64: Int] = [:]
        
        var hadInvalidLogits = false
        
        for step in 0..<maxDecodeSteps {
            if Date().timeIntervalSince(decodeStart) > decodeTimeBudgetSeconds {
                DebugLogger.translation("Stopping decode early (time budget exceeded). steps=\(step)", level: .warning)
                break
            }
            
            let lastToken = outputTokens.last!
            // EOS check
            if lastToken == eosToken { 
                DebugLogger.translation("Hit EOS at step \(step)", level: .debug)
                break 
            } 
            
            // Prepare Decoder Input
            let currentSeqLen = outputTokens.count
            
            // IMPORTANT:
            // Although the CoreML model declares RangeDim(1, 512), these decoder exports were traced and
            // often only behave correctly when fed a fixed length sequence (512). Using a shorter
            // `decoder_input_ids` can yield NaN/-inf logits on Simulator and sometimes even on device.
            // So we keep the decoder_input_ids shape fixed to maxLen and pad with pad_token_id.
            let usedDecoderLen = min(currentSeqLen, maxLen)
            let decoderInputIds = try MLMultiArray(shape: [NSNumber(value: batchSize), NSNumber(value: maxLen)], dataType: .int32)
            for i in 0..<maxLen {
                decoderInputIds[i] = NSNumber(value: padToken)
            }
            for i in 0..<usedDecoderLen {
                decoderInputIds[i] = NSNumber(value: outputTokens[i])
            }
            
            // Decoder inputs: decoder_input_ids (or input_ids), encoder_hidden_states, encoder_attention_mask
            let tokenInputName = decoder.modelDescription.inputDescriptionsByName.keys.contains("decoder_input_ids") ? "decoder_input_ids" : "input_ids"
            
            let decoderInput = try MLDictionaryFeatureProvider(dictionary: [
                tokenInputName: decoderInputIds,
                "encoder_hidden_states": encoderHiddenState,
                "encoder_attention_mask": attentionMaskMultiArray
            ])
            
        // Run Decoder
            let decoderOutput = try decoder.prediction(from: decoderInput)
            
            // Extract logits
            let logitsName = decoderOutput.featureNames.first { $0.contains("logits") } ?? "logits"
            guard let logits = decoderOutput.featureValue(for: logitsName)?.multiArrayValue else {
                DebugLogger.translation("No logits found in decoder output", level: .error)
                break 
            }
        
        if step == 0 {
            DebugLogger.translation("Decoder logits shape: \(logits.shape.map { $0.intValue }), type=\(logits.dataType.rawValue)", level: .debug)
        }
            
        // Greedy select next token from LAST position in logits.
        // Depending on conversion, logits can be:
        // - [1, seqLen, vocab]
        // - [seqLen, vocab]
        // - [1, vocab]   (when traced with seqLen=1, some converters squeeze)
        // - [vocab]
        let shape = logits.shape.map { $0.intValue }
        let vocabSize: Int
        // Even though logits may have seqLen=maxLen, we want the logits corresponding to the last real token.
        let lastIdx = usedDecoderLen - 1
            
            var maxProb: Float = -Float.infinity
            var nextToken: Int32 = 0
            
            // Efficiently find max (use raw buffer reads so Float16 logits work correctly)
        func valueAt(v: Int) -> Float {
            switch shape.count {
            case 3:
                return readFloat(logits, indices: [0, lastIdx, v])
            case 2:
                // Could be [seqLen, vocab] or [1, vocab]
                if shape[0] == 1 {
                    return readFloat(logits, indices: [0, v])
                } else {
                    return readFloat(logits, indices: [lastIdx, v])
                }
            case 1:
                return readFloat(logits, indices: [v])
            default:
                return -Float.infinity
            }
        }
        
        if shape.count >= 1 {
            vocabSize = shape.last ?? 0
        } else {
            vocabSize = 0
        }
        
        if vocabSize == 0 {
            DebugLogger.translation("Invalid logits shape: \(shape)", level: .error)
            break
        }
        
        for v in 0..<vocabSize {
            let val = valueAt(v: v)
            if val.isNaN { continue }
            if val > maxProb {
                maxProb = val
                nextToken = Int32(v)
            }
        }
        
        if maxProb == -Float.infinity {
            hadInvalidLogits = true
            DebugLogger.translation("Decoder produced only NaN/-inf logits (shape=\(shape)). Aborting decode.", level: .error)
            break
        }
        
        if step == 0 {
            DebugLogger.translation("Step0 argmax token=\(nextToken) score=\(maxProb)", level: .debug)
        }
            
            // DebugLogger.translation("Step \(step): Token \(nextToken) (Prob \(maxProb))", level: .debug)
            
            outputTokens.append(nextToken)
            
            // Repetition guard: stop if we get stuck in a loop (common with greedy decoding).
            if outputTokens.count >= 2 {
                let a = UInt32(bitPattern: outputTokens[outputTokens.count - 2])
                let b = UInt32(bitPattern: outputTokens[outputTokens.count - 1])
                let key = (UInt64(a) << 32) | UInt64(b)
                let newCount = (bigramCounts[key] ?? 0) + 1
                bigramCounts[key] = newCount
                #if targetEnvironment(simulator)
                let repeatThreshold = 3
                #else
                let repeatThreshold = 6
                #endif
                if newCount >= repeatThreshold {
                    DebugLogger.translation("Stopping decode early (repetition loop detected). bigram=(\(a),\(b))", level: .warning)
                    break
                }
            }
            
            // Special-case common alternation loop: ", X, X" patterns like "Money, money, money..."
            // If we detect [comma, w, comma, w] we stop early and return the partial translation.
            if outputTokens.count >= 5 {
                let t1 = outputTokens[outputTokens.count - 4]
                let t2 = outputTokens[outputTokens.count - 3]
                let t3 = outputTokens[outputTokens.count - 2]
                let t4 = outputTokens[outputTokens.count - 1]
                // Token id 2 is "," in your vocab (seen in logs).
                if t1 == 2 && t3 == 2 && t2 == t4 {
                    DebugLogger.translation("Stopping decode early (alternating repetition detected). pattern=[2,\(t2),2,\(t4)]", level: .warning)
                    break
                }
            }
            
            // Secondary EOS check
            if nextToken == eosToken { 
                DebugLogger.translation("Hit EOS (Secondary) at step \(step)", level: .debug)
                break 
            }
        }
        
        DebugLogger.translation("Final Output Tokens: \(outputTokens)", level: .debug)
        
        // 4. Detokenize
        let decoded = tokenizer.detokenize(outputTokens)
        if hadInvalidLogits {
            // Provide a more actionable error, but after logging final tokens/detokenize.
            throw TranslationError.translationFailed(
                "Opus‑MT model produced invalid logits. This can happen on iOS Simulator with MLProgram float16 models. Try a real device or re-convert with FLOAT32 precision (and ideally export last-token logits)."
            )
        }
        return decoded
    }
    
    // MARK: - Helpers
    
    private func convertToFP32(_ input: MLMultiArray) throws -> MLMultiArray {
        if input.dataType == .float32 { return input }
        
        let output = try MLMultiArray(shape: input.shape, dataType: .float32)
        let count = input.count
        
        switch input.dataType {
        case .float16:
            // Decode IEEE 754 halfs from raw storage
            let src = input.dataPointer.bindMemory(to: UInt16.self, capacity: count)
            let dst = output.dataPointer.bindMemory(to: Float.self, capacity: count)
            for i in 0..<count {
                dst[i] = Float(Float16(bitPattern: src[i]))
            }
        case .double:
            let src = input.dataPointer.bindMemory(to: Double.self, capacity: count)
            let dst = output.dataPointer.bindMemory(to: Float.self, capacity: count)
            for i in 0..<count {
                dst[i] = Float(src[i])
            }
        case .int32:
            let src = input.dataPointer.bindMemory(to: Int32.self, capacity: count)
            let dst = output.dataPointer.bindMemory(to: Float.self, capacity: count)
            for i in 0..<count {
                dst[i] = Float(src[i])
            }
        default:
            // Fallback (slower)
            for i in 0..<count {
                output[i] = NSNumber(value: input[i].floatValue)
            }
        }
        
        return output
    }

    /// Read a single element from an MLMultiArray as Float, correctly handling Float16.
    private func readFloat(_ array: MLMultiArray, indices: [Int]) -> Float {
        // Compute flat offset using strides
        let strides = array.strides.map { $0.intValue }
        var offset = 0
        for (i, idx) in indices.enumerated() {
            offset += idx * strides[i]
        }

        switch array.dataType {
        case .float32:
            let ptr = array.dataPointer.bindMemory(to: Float.self, capacity: array.count)
            return ptr[offset]
        case .float16:
            // MLMultiArray stores float16 as 16-bit IEEE 754; decode via bitPattern to avoid NaN mishaps.
            let ptr = array.dataPointer.bindMemory(to: UInt16.self, capacity: array.count)
            return Float(Float16(bitPattern: ptr[offset]))
        case .double:
            let ptr = array.dataPointer.bindMemory(to: Double.self, capacity: array.count)
            return Float(ptr[offset])
        default:
            // Fallback (slower) path
            return array[offset].floatValue
        }
    }
    
    // MARK: - Debug Helpers
    
    private func debugPrintInputDescription(model: MLModel, name: String) {
        let inputs = model.modelDescription.inputDescriptionsByName
        var log = "\(name) Inputs: "
        for (key, feature) in inputs {
            log += "\(key) (\(feature.type)), "
        }
        DebugLogger.translation(log, level: .debug)
    }
    
    // MARK: - Legacy / Unused Logic
    
    // Legacy methods required for Gemma inference path (until that is refactored)
    
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
        // Log that demo mode is being used
        DebugLogger.translation("Using demo translation - no models available", level: .warning)
        
        return """
        ⚠️ Demo Mode
        
        No translation models are installed yet.
        
        To enable real translation:
        1. Go to Settings → Models
        2. Download Opus-MT or Gemma AI models
        3. Come back here and try again!
        
        Your text: "\(text)"
        """
    }
    
    // MARK: - Smart Positioning Translation (Gemma 3n E2B)
    
    /// Translate text blocks with smart positioning for overlay display
    /// Uses Gemma 3n E2B to understand UI context and adjust translations
    func translateWithPositioning(
        textBlocks: [ScreenTextBlock],
        from sourceLanguage: Language,
        to targetLanguage: Language,
        screenSize: CGSize
    ) async throws -> [PositionedTranslation] {
        
        guard !textBlocks.isEmpty else {
            return []
        }
        
        isProcessing = true
        error = nil
        
        do {
            // Check if Gemma is available
            let useGemma = isModelAvailable(.gemma3n)
            
            if useGemma {
                // Try smart translation with Gemma
                let result = try await performGemmaPositionedTranslation(
                    textBlocks: textBlocks,
                    from: sourceLanguage,
                    to: targetLanguage,
                    screenSize: screenSize
                )
                isProcessing = false
                return result
            } else {
                // Fallback to simple translation without smart positioning
                let result = try await performSimplePositionedTranslation(
                    textBlocks: textBlocks,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                isProcessing = false
                return result
            }
            
        } catch {
            isProcessing = false
            throw error
        }
    }
    
    /// Perform translation with Gemma 3n for smart UI understanding
    private func performGemmaPositionedTranslation(
        textBlocks: [ScreenTextBlock],
        from sourceLanguage: Language,
        to targetLanguage: Language,
        screenSize: CGSize
    ) async throws -> [PositionedTranslation] {
        
        // Build the prompt for Gemma
        let prompt = buildPositioningPrompt(
            textBlocks: textBlocks,
            from: sourceLanguage,
            to: targetLanguage,
            screenSize: screenSize
        )
        
        // Try to load Gemma if not already loaded
        if !loadedModels.contains(.gemma3n) {
            try await loadModel(.gemma3n)
        }
        
        guard let model = models[.gemma3n] else {
            throw TranslationError.modelNotLoaded("Gemma 3n E2B")
        }
        
        // Run inference
        let config = self.configuration
        let responseText = try await withTimeout(15.0) { [self] in
            try await withCheckedThrowingContinuation { continuation in
                self.processingQueue.async {
                    do {
                        let result = try self.runGemmaInference(
                            model: model,
                            text: prompt,
                            targetLanguage: targetLanguage,
                            configuration: config
                        )
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        // Parse Gemma's JSON response
        let positionedTranslations = parseGemmaPositioningResponse(
            response: responseText,
            originalBlocks: textBlocks,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        
        return positionedTranslations
    }
    
    /// Build prompt for Gemma positioning translation
    private func buildPositioningPrompt(
        textBlocks: [ScreenTextBlock],
        from sourceLanguage: Language,
        to targetLanguage: Language,
        screenSize: CGSize
    ) -> String {
        var prompt = """
        You are a UI translator. Translate the following text blocks from \(sourceLanguage.name) to \(targetLanguage.name).
        For each block, provide the translation and adjust the position if the translation is significantly longer or shorter.
        
        Screen size: \(Int(screenSize.width))x\(Int(screenSize.height))
        
        Text blocks:
        
        """
        
        for (index, block) in textBlocks.enumerated() {
            let box = block.boundingBox
            prompt += """
            \(index + 1). "\(block.text)"
               Position: x=\(String(format: "%.3f", box.minX)), y=\(String(format: "%.3f", box.minY)), w=\(String(format: "%.3f", box.width)), h=\(String(format: "%.3f", box.height))
               Type: \(block.blockType.rawValue)
               Confidence: \(String(format: "%.2f", block.confidence))
            
            """
        }
        
        prompt += """
        
        Respond with a JSON array. For each block:
        {
          "index": <block number>,
          "translation": "<translated text>",
          "type": "header|body|button|label|navigation|unknown",
          "adjusted_x": <0-1>,
          "adjusted_y": <0-1>,
          "adjusted_w": <0-1>,
          "adjusted_h": <0-1>,
          "font_scale": <0.5-2.0>
        }
        
        JSON output only, no explanation:
        """
        
        return prompt
    }
    
    /// Parse Gemma's JSON response into PositionedTranslations
    private func parseGemmaPositioningResponse(
        response: String,
        originalBlocks: [ScreenTextBlock],
        sourceLanguage: Language,
        targetLanguage: Language
    ) -> [PositionedTranslation] {
        
        var results: [PositionedTranslation] = []
        
        // Try to extract JSON from response
        let jsonString = extractJSON(from: response)
        
        guard let data = jsonString.data(using: .utf8) else {
            // Fallback: return original blocks with empty translations
            return createFallbackTranslations(
                blocks: originalBlocks,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        }
        
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for item in jsonArray {
                    guard let index = item["index"] as? Int,
                          let translation = item["translation"] as? String,
                          index > 0 && index <= originalBlocks.count else {
                        continue
                    }
                    
                    let block = originalBlocks[index - 1]
                    
                    // Parse adjusted position
                    let adjustedRect = CGRect(
                        x: item["adjusted_x"] as? CGFloat ?? block.boundingBox.minX,
                        y: item["adjusted_y"] as? CGFloat ?? block.boundingBox.minY,
                        width: item["adjusted_w"] as? CGFloat ?? block.boundingBox.width,
                        height: item["adjusted_h"] as? CGFloat ?? block.boundingBox.height
                    )
                    
                    let fontScale = item["font_scale"] as? CGFloat ?? 1.0
                    let typeString = item["type"] as? String ?? block.blockType.rawValue
                    let blockType = TextBlockType(rawValue: typeString) ?? block.blockType
                    
                    let positioned = PositionedTranslation(
                        originalText: block.text,
                        translatedText: translation,
                        blockType: blockType,
                        originalRect: block.boundingBox,
                        adjustedRect: adjustedRect,
                        fontScale: fontScale,
                        sourceLanguage: sourceLanguage.id,
                        targetLanguage: targetLanguage.id
                    )
                    
                    results.append(positioned)
                }
            }
        } catch {
            // JSON parsing failed, use fallback
            return createFallbackTranslations(
                blocks: originalBlocks,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        }
        
        // If we got fewer results than blocks, fill in missing ones
        if results.count < originalBlocks.count {
            let missing = createFallbackTranslations(
                blocks: Array(originalBlocks[results.count...]),
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            results.append(contentsOf: missing)
        }
        
        return results
    }
    
    /// Extract JSON from a response that might contain extra text
    private func extractJSON(from text: String) -> String {
        // Find the first '[' and last ']'
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]") else {
            return "[]"
        }
        return String(text[start...end])
    }
    
    /// Create fallback translations when Gemma parsing fails
    private func createFallbackTranslations(
        blocks: [ScreenTextBlock],
        sourceLanguage: Language,
        targetLanguage: Language
    ) -> [PositionedTranslation] {
        return blocks.map { block in
            PositionedTranslation(
                originalText: block.text,
                translatedText: "[Translation pending]",
                blockType: block.blockType,
                originalRect: block.boundingBox,
                adjustedRect: nil,
                fontScale: block.blockType.suggestedFontScale,
                sourceLanguage: sourceLanguage.id,
                targetLanguage: targetLanguage.id
            )
        }
    }
    
    /// Simple positioned translation without Gemma (fallback)
    private func performSimplePositionedTranslation(
        textBlocks: [ScreenTextBlock],
        from sourceLanguage: Language,
        to targetLanguage: Language
    ) async throws -> [PositionedTranslation] {
        
        var results: [PositionedTranslation] = []
        
        for block in textBlocks {
            // Translate each block individually
            let translationResult = try await translate(
                text: block.text,
                from: sourceLanguage,
                to: targetLanguage
            )
            
            let positioned = PositionedTranslation(
                originalText: block.text,
                translatedText: translationResult.translatedText,
                blockType: block.blockType,
                originalRect: block.boundingBox,
                adjustedRect: nil, // Use original position
                fontScale: block.blockType.suggestedFontScale,
                sourceLanguage: sourceLanguage.id,
                targetLanguage: targetLanguage.id
            )
            
            results.append(positioned)
        }
        
        return results
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
