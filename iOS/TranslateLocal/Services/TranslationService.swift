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
    case gemma3n = "Gemma3nE2B"
    case opusEnJa = "OpusMT_en_ja"
    case opusEnZh = "OpusMT_en_zh"
    case opusEnEs = "OpusMT_en_es"
    case opusEnFr = "OpusMT_en_fr"
    case opusEnDe = "OpusMT_en_de"
    case opusEnKo = "OpusMT_en_ko"
    
    var displayName: String {
        switch self {
        case .gemma3n: return "Gemma 3n (Multilingual)"
        case .opusEnJa: return "Opus EN→JA"
        case .opusEnZh: return "Opus EN→ZH"
        case .opusEnEs: return "Opus EN→ES"
        case .opusEnFr: return "Opus EN→FR"
        case .opusEnDe: return "Opus EN→DE"
        case .opusEnKo: return "Opus EN→KO"
        }
    }
    
    var sourceLanguage: Language? {
        switch self {
        case .gemma3n: return nil  // Multilingual
        default: return .english
        }
    }
    
    var targetLanguage: Language? {
        switch self {
        case .gemma3n: return nil
        case .opusEnJa: return .japanese
        case .opusEnZh: return .chinese
        case .opusEnEs: return .spanish
        case .opusEnFr: return .french
        case .opusEnDe: return .german
        case .opusEnKo: return .korean
        }
    }
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
@MainActor
class TranslationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isProcessing = false
    @Published private(set) var loadedModels: Set<TranslationModelType> = []
    @Published private(set) var error: TranslationError?
    @Published var configuration = TranslationConfiguration.default
    
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
            
            // Ensure model is loaded
            if !loadedModels.contains(modelType) {
                try await loadModel(modelType)
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
        // First, check if we have a specialized Opus model for this pair
        if source == .english {
            switch target.id {
            case "ja": return .opusEnJa
            case "zh": return .opusEnZh
            case "es": return .opusEnEs
            case "fr": return .opusEnFr
            case "de": return .opusEnDe
            case "ko": return .opusEnKo
            default: break
            }
        }
        
        // Fall back to Gemma for other pairs
        return .gemma3n
    }
    
    private func performTranslation(
        text: String,
        from sourceLanguage: Language,
        to targetLanguage: Language,
        using modelType: TranslationModelType
    ) async throws -> String {
        
        guard let model = models[modelType] else {
            throw TranslationError.modelNotLoaded(modelType.displayName)
        }
        
        // This is a placeholder for actual model inference
        // Real implementation would:
        // 1. Tokenize input text
        // 2. Create MLMultiArray input
        // 3. Run model prediction
        // 4. Decode output tokens
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let result = try self.runModelInference(
                        model: model,
                        text: text,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        modelType: modelType
                    )
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func runModelInference(
        model: MLModel,
        text: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        modelType: TranslationModelType
    ) throws -> String {
        
        // For Gemma-style models, we construct a prompt
        if modelType == .gemma3n {
            return try runGemmaInference(model: model, text: text, targetLanguage: targetLanguage)
        }
        
        // For Opus-MT encoder-decoder models
        return try runOpusInference(model: model, text: text)
    }
    
    private func runGemmaInference(
        model: MLModel,
        text: String,
        targetLanguage: Language
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
        text: String
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
        case .unsupportedLanguagePair:
            return "This language pair is not supported"
        case .invalidModelOutput:
            return "Invalid output from translation model"
        }
    }
}
