//
//  GemmaService.swift
//  TranslateLocal
//
//  Provides Gemma 3n E2B inference for translation and PiP analysis
//  Uses MLX Swift LM for on-device LLM inference
//
//  NOTE: MLX requires real Apple Silicon GPU. On simulator, this service
//  will compile but operations will fail gracefully.
//

import Foundation
import MLXLLM
import MLXLMCommon
import MLX
import UIKit

// MARK: - Gemma Service

/// Gemma 3n service using MLX for on-device LLM inference
@MainActor @Observable
class GemmaService {
    
    // MARK: - Singleton
    
    static let shared = GemmaService()
    
    // MARK: - Observable Properties
    
    private(set) var isLoaded = false
    private(set) var isProcessing = false
    private(set) var error: String?
    private(set) var lastGenerationTime: TimeInterval = 0
    private(set) var tokensPerSecond: Double = 0
    
    // MARK: - Private Properties
    
    private var modelContainer: ModelContainer?
    private let mlxManager = MLXModelManager.shared
    
    // Generation parameters
    private let maxTokens = 256
    private let temperature: Float = 0.7
    
    // MARK: - Initialization
    
    private init() {
        setupMemoryWarningObserver()
        
        #if targetEnvironment(simulator)
        DebugLogger.model("⚠️ GemmaService: Running on Simulator - MLX GPU operations will not work", level: .warning)
        #else
        DebugLogger.model("GemmaService initialized", level: .info)
        #endif
    }
    
    // MARK: - Model Loading
    
    /// Load the Gemma model into memory
    func loadModel() async throws {
        guard !isLoaded else {
            DebugLogger.model("Gemma already loaded, skipping", level: .debug)
            return
        }
        
        // Fail gracefully on simulator
        #if targetEnvironment(simulator)
        let simulatorError = "MLX requires Apple Silicon GPU. Cannot run on Simulator."
        self.error = simulatorError
        DebugLogger.model("⚠️ \(simulatorError)", level: .error)
        throw GemmaError.loadFailed(simulatorError)
        #else
        
        // Don't hard-fail based on a filesystem check. The MLX LM library manages its own cache.
        // If the cache is missing, loadContainer will throw and we surface the real error.
        if !mlxManager.isGemmaReady {
            DebugLogger.model("Gemma not marked as downloaded; attempting load anyway (may trigger download in library cache)", level: .warning)
            // If the user hasn't finished the download flow, this might hang or fail.
        } else {
            // Validate disk space before loading to prevent crashes on low memory devices
            if mlxManager.hasSufficientDiskSpaceForLoad() == false {
                 DebugLogger.model("⚠️ Low disk space detected. Loading Gemma might fail.", level: .warning)
            }
        }
        
        DebugLogger.model("Loading Gemma model...", level: .info)
        
        do {
            // Configure GPU memory limit for mobile
            MLX.GPU.set(cacheLimit: 1024 * 1024 * 1024) // 1GB cache limit
            
            // Load model using MLX Swift LM simplified API
            let modelConfiguration = ModelConfiguration(id: mlxManager.gemmaModelId)
            
            modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) { progress in
                DebugLogger.model("Loading progress: \(Int(progress.fractionCompleted * 100))%", level: .debug)
            }
            
            isLoaded = true
            // Mark ready for UI.
            mlxManager.checkGemmaStatus()
            DebugLogger.model("Gemma model loaded successfully", level: .success)
            
        } catch {
            self.error = error.localizedDescription
            DebugLogger.model("Failed to load Gemma: \(error.localizedDescription)", level: .error)
            throw GemmaError.loadFailed(error.localizedDescription)
        }
        #endif
    }
    
    /// Unload model to free memory
    func unloadModel() {
        modelContainer = nil
        isLoaded = false
        
        // Clear GPU cache
        MLX.GPU.clearCache()
        
        DebugLogger.model("Gemma model unloaded", level: .info)
    }
    
    // MARK: - Translation
    
    /// Translate text from source to target language
    func translate(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> String {
        
        guard isLoaded, let container = modelContainer else {
            throw GemmaError.modelNotLoaded
        }
        
        guard !text.isEmpty else {
            throw GemmaError.emptyInput
        }
        
        isProcessing = true
        error = nil
        
        let startTime = Date()
        
        // Build translation prompt
        // Build translation prompt using Gemma 3n chat format
        // Check for glossary entries
        let glossaryEntries = GlossaryService.shared.getApplicableEntries(for: text)
        var glossaryContext = ""
        
        if !glossaryEntries.isEmpty {
            let terms = glossaryEntries.map { "- \($0.sourceText) -> \($0.targetText)" }.joined(separator: "\n")
            glossaryContext = """
            
            Use these specific translations:
            \(terms)
            """
            
            // Log that we're using glossary
            DebugLogger.translation("Using \(glossaryEntries.count) glossary entries", level: .info)
            GlossaryService.shared.batchIncrementUsage(for: glossaryEntries)
        }
        
        // Build translation prompt using Gemma 3n chat format
        let prompt = """
        <start_of_turn>user
        Translate the following text from \(sourceLanguage) to \(targetLanguage). Output only the translation, nothing else.\(glossaryContext)
        
        Text: \(text)<end_of_turn>
        <start_of_turn>model
        """
        
        DebugLogger.translation("Gemma translating from \(sourceLanguage) to \(targetLanguage): \(text.prefix(50))...", level: .info)
        
        do {
            // Generate translation using ModelContainer's generate API
            let result = try await generateWithContainer(prompt: prompt, container: container)
            
            // Clean up the output
            let translation = cleanTranslationOutput(result, originalText: text)
            
            let processingTime = Date().timeIntervalSince(startTime)
            lastGenerationTime = processingTime
            
            DebugLogger.translation("Gemma translation completed in \(String(format: "%.2f", processingTime))s", level: .success)
            
            isProcessing = false
            return translation
            
        } catch {
            isProcessing = false
            self.error = error.localizedDescription
            DebugLogger.translation("Gemma translation failed: \(error.localizedDescription)", level: .error)
            throw GemmaError.generationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - PiP Analysis
    
    /// Analyze screen content for PiP smart features
    func analyzeForPiP(textBlocks: [String]) async throws -> PiPAnalysis {
        
        guard isLoaded, let container = modelContainer else {
            throw GemmaError.modelNotLoaded
        }
        
        guard !textBlocks.isEmpty else {
            return PiPAnalysis(summary: "", contentType: "unknown", suggestedActions: [])
        }
        
        isProcessing = true
        
        let joinedText = textBlocks.joined(separator: "\n")
        let prompt = """
        <start_of_turn>user
        Analyze the following text from a mobile screen. Respond with JSON containing:
        - content_type: one of (article, chat, menu, form, video, social, unknown)
        - summary: brief summary (max 20 words)
        - suggested_actions: list of actions
        
        Text:
        \(joinedText)<end_of_turn>
        <start_of_turn>model
        """
        
        do {
            let result = try await generateWithContainer(prompt: prompt, container: container, maxTokens: 150)
            let analysis = parsePiPAnalysis(result)
            
            isProcessing = false
            return analysis
            
        } catch {
            isProcessing = false
            throw GemmaError.generationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - General Generation
    
    /// Generate text from a prompt (non-streaming)
    func generate(prompt: String, maxTokens: Int = 256) async throws -> String {
        guard isLoaded, let container = modelContainer else {
            throw GemmaError.modelNotLoaded
        }
        
        return try await generateWithContainer(prompt: prompt, container: container, maxTokens: maxTokens)
    }
    
    // MARK: - Private Methods
    
    /// Generate text using the ModelContainer
    private func generateWithContainer(prompt: String, container: ModelContainer, maxTokens: Int = 256) async throws -> String {
        
        let startTime = Date()
        var outputText = ""
        var tokenCount = 0
        
        // Create UserInput from prompt
        let userInput = UserInput(prompt: prompt)
        
        // Prepare input using container
        let input = try await container.prepare(input: userInput)
        
        // Create generation parameters
        let parameters = GenerateParameters(
            maxTokens: maxTokens,
            temperature: temperature
        )
        
        // Generate tokens using container's generate method (needs to be awaited for actor isolation)
        let stream = try await container.perform { context in
            try MLXLMCommon.generate(
                input: input,
                parameters: parameters,
                context: context
            )
        }
        
        for await generation in stream {
            switch generation {
            case .chunk(let text):
                outputText += text
                tokenCount += 1
            case .info(let info):
                tokensPerSecond = info.tokensPerSecond
            case .toolCall:
                // Tool calls not used for translation
                break
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        if elapsed > 0 && tokenCount > 0 {
            tokensPerSecond = Double(tokenCount) / elapsed
        }
        
        return outputText
    }
    
    private func cleanTranslationOutput(_ output: String, originalText: String) -> String {
        var cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common prefixes that models sometimes add
        let prefixesToRemove = [
            "Translation:",
            "Here is the translation:",
            "Translated text:",
            "Output:",
        ]
        
        for prefix in prefixesToRemove {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Remove quotes if present
        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        
        return cleaned
    }
    
    private func parsePiPAnalysis(_ response: String) -> PiPAnalysis {
        // Try to parse JSON response
        if let data = response.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            let contentType = json["content_type"] as? String ?? "unknown"
            let summary = json["summary"] as? String ?? ""
            let suggestions = json["suggested_actions"] as? [String] ?? []
            
            return PiPAnalysis(summary: summary, contentType: contentType, suggestedActions: suggestions)
        }
        
        // Fallback if JSON parsing fails
        return PiPAnalysis(summary: response.prefix(100).description, contentType: "unknown", suggestedActions: [])
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
    }
    
    private func handleMemoryWarning() {
        if isLoaded && !isProcessing {
            DebugLogger.model("Memory warning received - unloading Gemma", level: .warning)
            unloadModel()
        }
    }
    
    /// Clear any error state
    func clearError() {
        error = nil
    }
}

// MARK: - PiP Analysis Result

struct PiPAnalysis {
    let summary: String
    let contentType: String  // "article", "chat", "menu", "form", "video", "social", "unknown"
    let suggestedActions: [String]
}

// MARK: - Gemma Errors

enum GemmaError: LocalizedError {
    case modelNotDownloaded
    case modelNotLoaded
    case loadFailed(String)
    case emptyInput
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotDownloaded:
            return "Gemma model is not downloaded. Please download it first."
        case .modelNotLoaded:
            return "Gemma model is not loaded into memory"
        case .loadFailed(let reason):
            return "Failed to load Gemma: \(reason)"
        case .emptyInput:
            return "Input text cannot be empty"
        case .generationFailed(let reason):
            return "Generation failed: \(reason)"
        }
    }
}
