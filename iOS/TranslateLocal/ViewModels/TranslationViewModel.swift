//
//  TranslationViewModel.swift
//  TranslateLocal
//
//  View model for translation operations
//

import Foundation
import Combine
import UIKit

@MainActor
class TranslationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var sourceText: String = ""
    @Published var translatedText: String = ""
    @Published var sourceLanguage: Language = .english
    @Published var targetLanguage: Language = .japanese
    @Published var isTranslating = false
    @Published var error: String?
    @Published var lastResult: TranslationResult?
    
    // Statistics
    @Published var processingTime: TimeInterval = 0
    @Published var modelUsed: String = ""
    
    // MARK: - Dependencies
    
    private let translationService: TranslationService
    private let ocrService: OCRService
    private let historyManager: HistoryManager
    
    // MARK: - Private Properties
    
    private var translationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // Debouncing
    private let debounceInterval: TimeInterval = 0.5
    
    // MARK: - Initialization
    
    init(
        translationService: TranslationService,
        ocrService: OCRService,
        historyManager: HistoryManager = HistoryManager()
    ) {
        self.translationService = translationService
        self.ocrService = ocrService
        self.historyManager = historyManager
        
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Auto-translate when source text changes (debounced)
        $sourceText
            .debounce(for: .seconds(debounceInterval), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard !text.isEmpty else {
                    self?.translatedText = ""
                    return
                }
                Task {
                    await self?.translate()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Translation
    
    /// Translate the current source text
    func translate() async {
        // Cancel any pending translation
        translationTask?.cancel()
        
        guard !sourceText.isEmpty else {
            translatedText = ""
            return
        }
        
        isTranslating = true
        error = nil
        
        translationTask = Task {
            do {
                let result = try await translationService.translate(
                    text: sourceText,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                guard !Task.isCancelled else { return }
                
                self.translatedText = result.translatedText
                self.processingTime = result.processingTime
                self.modelUsed = result.modelUsed
                self.lastResult = result
                
                // Save to history
                saveToHistory(result)
                
            } catch {
                guard !Task.isCancelled else { return }
                self.error = error.localizedDescription
            }
            
            self.isTranslating = false
        }
    }
    
    /// Translate text from an image
    func translateImage(_ image: UIImage) async -> [TranslatedTextBlock] {
        isTranslating = true
        error = nil
        
        var translatedBlocks: [TranslatedTextBlock] = []
        
        do {
            // Perform OCR
            let ocrResult = try await ocrService.recognizeText(from: image)
            
            // Translate each block
            for block in ocrResult.textBlocks {
                let translation = try await translationService.translate(
                    text: block.text,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                let translatedBlock = TranslatedTextBlock(
                    originalText: block.text,
                    translatedText: translation.translatedText,
                    boundingBox: block.boundingBox,
                    confidence: block.confidence
                )
                
                translatedBlocks.append(translatedBlock)
            }
            
            // Create combined result for history
            let combinedSource = translatedBlocks.map(\.originalText).joined(separator: "\n")
            let combinedTranslation = translatedBlocks.map(\.translatedText).joined(separator: "\n")
            
            self.sourceText = combinedSource
            self.translatedText = combinedTranslation
            
        } catch {
            self.error = error.localizedDescription
        }
        
        isTranslating = false
        return translatedBlocks
    }
    
    /// Swap source and target languages
    func swapLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
        
        // Also swap the text
        let tempText = sourceText
        sourceText = translatedText
        translatedText = tempText
        
        // Re-translate with swapped languages
        Task {
            await translate()
        }
    }
    
    /// Clear all text
    func clear() {
        sourceText = ""
        translatedText = ""
        error = nil
        lastResult = nil
    }
    
    // MARK: - Clipboard Operations
    
    func copyTranslation() {
        guard !translatedText.isEmpty else { return }
        UIPasteboard.general.string = translatedText
    }
    
    func copySourceText() {
        guard !sourceText.isEmpty else { return }
        UIPasteboard.general.string = sourceText
    }
    
    func pasteFromClipboard() {
        if let text = UIPasteboard.general.string {
            sourceText = text
        }
    }
    
    // MARK: - History
    
    private func saveToHistory(_ result: TranslationResult) {
        let item = TranslationHistoryItem(
            sourceText: result.sourceText,
            translatedText: result.translatedText,
            sourceLanguage: result.sourceLanguage.id,
            targetLanguage: result.targetLanguage.id
        )
        
        historyManager.addItem(item)
    }
    
    /// Load a translation from history
    func loadFromHistory(_ item: TranslationHistoryItem) {
        sourceText = item.sourceText
        translatedText = item.translatedText
        
        if let source = Language.from(code: item.sourceLanguage) {
            sourceLanguage = source
        }
        if let target = Language.from(code: item.targetLanguage) {
            targetLanguage = target
        }
    }
    
    // MARK: - Text Analysis
    
    var sourceCharacterCount: Int {
        sourceText.count
    }
    
    var translatedCharacterCount: Int {
        translatedText.count
    }
    
    var estimatedReadingTime: TimeInterval {
        // Average reading speed: ~200 words per minute
        let wordCount = translatedText.split(separator: " ").count
        return Double(wordCount) / 200.0 * 60.0
    }
    
    var characterRatio: Double {
        guard sourceCharacterCount > 0 else { return 0 }
        return Double(translatedCharacterCount) / Double(sourceCharacterCount)
    }
}

// MARK: - Language Extensions

extension Language {
    /// Get language flag emoji
    var flag: String {
        switch id {
        case "en": return "🇺🇸"
        case "ja": return "🇯🇵"
        case "zh": return "🇨🇳"
        case "ko": return "🇰🇷"
        case "es": return "🇪🇸"
        case "fr": return "🇫🇷"
        case "de": return "🇩🇪"
        case "ru": return "🇷🇺"
        case "ar": return "🇸🇦"
        case "pt": return "🇧🇷"
        default: return "🌐"
        }
    }
}
