//
//  MLXModelManager.swift
//  TranslateLocal
//
//  Manages MLX model downloads and caching for Gemma 3n E2B
//  Uses MLX Swift LM framework for on-device LLM inference
//

import Foundation
import MLXLLM
import MLXLMCommon
import MLX

// MARK: - MLX Model Manager

/// Manages MLX model downloads from HuggingFace and local caching
@MainActor @Observable
class MLXModelManager {
    
    // MARK: - Singleton
    
    static let shared = MLXModelManager()
    
    // MARK: - Observable Properties
    
    private(set) var isDownloading = false
    private(set) var downloadProgress: Double = 0
    private(set) var downloadedBytes: Int64 = 0
    private(set) var totalBytes: Int64 = 0
    private(set) var isGemmaReady = false
    private(set) var error: String?
    private(set) var statusMessage: String = ""
    
    // MARK: - Constants
    
    /// HuggingFace model ID for Gemma 3n E2B (4-bit quantized for mobile)
    let gemmaModelId = "mlx-community/gemma-3n-E2B-it-lm-4bit"
    
    /// Estimated model size in bytes (~1.5 GB)
    let estimatedSizeBytes: Int64 = 1_500_000_000
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let modelsDirectory: URL
    private var downloadTask: Task<Void, Error>?
    
    // MARK: - Computed Properties
    
    /// Formatted download progress string
    var progressText: String {
        if totalBytes > 0 {
            let downloadedMB = Double(downloadedBytes) / 1_000_000
            let totalMB = Double(totalBytes) / 1_000_000
            return String(format: "%.1f / %.1f MB", downloadedMB, totalMB)
        } else {
            return String(format: "%.0f%%", downloadProgress * 100)
        }
    }
    
    /// Formatted model size string
    var estimatedSizeText: String {
        ByteCountFormatter.string(fromByteCount: estimatedSizeBytes, countStyle: .file)
    }
    
    /// Path to the Gemma model directory
    var gemmaModelPath: URL {
        modelsDirectory.appendingPathComponent("gemma-3n-e2b", isDirectory: true)
    }
    
    // MARK: - Initialization
    
    private init() {
        // Set up models directory in Application Support
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("TranslateLocal/MLXModels", isDirectory: true)
        
        // Create directory if needed
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        // Check if Gemma is already downloaded
        checkGemmaStatus()
        
        DebugLogger.model("MLXModelManager initialized. Models directory: \(modelsDirectory.path)", level: .info)
    }
    
    // MARK: - Public Methods
    
    /// Check if Gemma model is downloaded and ready
    func checkGemmaStatus() {
        // Check for required model files
        let configPath = gemmaModelPath.appendingPathComponent("config.json")
        let tokenizerPath = gemmaModelPath.appendingPathComponent("tokenizer.json")
        
        let configExists = fileManager.fileExists(atPath: configPath.path)
        let tokenizerExists = fileManager.fileExists(atPath: tokenizerPath.path)
        
        // Check for model weights (safetensors files)
        var hasWeights = false
        if let contents = try? fileManager.contentsOfDirectory(atPath: gemmaModelPath.path) {
            hasWeights = contents.contains { $0.hasSuffix(".safetensors") }
        }
        
        isGemmaReady = configExists && tokenizerExists && hasWeights
        
        if isGemmaReady {
            DebugLogger.model("Gemma model is ready at: \(gemmaModelPath.path)", level: .success)
        } else {
            DebugLogger.model("Gemma model not found. Config: \(configExists), Tokenizer: \(tokenizerExists), Weights: \(hasWeights)", level: .debug)
        }
    }
    
    /// Download Gemma model from HuggingFace
    /// Uses MLX Swift LM's built-in model downloading
    func downloadGemma() async throws {
        guard !isDownloading else {
            throw MLXModelError.downloadInProgress
        }
        
        isDownloading = true
        downloadProgress = 0
        downloadedBytes = 0
        totalBytes = 0
        error = nil
        statusMessage = "Preparing download..."
        
        DebugLogger.model("Starting Gemma download from: \(gemmaModelId)", level: .info)
        
        do {
            // Use MLX Swift LM's built-in model loading which handles download
            // The loadModel function will download if not cached
            statusMessage = "Downloading model files..."
            
            // Create download task
            downloadTask = Task {
                // MLX Swift LM handles the download automatically when loading
                // We use a simplified approach - just trigger the load which downloads
                let modelConfiguration = ModelConfiguration(id: gemmaModelId)
                
                // This will download the model if not present
                _ = try await LLMModelFactory.shared.loadContainer(
                    configuration: modelConfiguration
                ) { progress in
                    Task { @MainActor in
                        self.downloadProgress = progress.fractionCompleted
                        self.statusMessage = "Downloading: \(Int(progress.fractionCompleted * 100))%"
                    }
                }
            }
            
            try await downloadTask?.value
            
            // Verify download succeeded
            checkGemmaStatus()
            
            if isGemmaReady {
                statusMessage = "Download complete!"
                DebugLogger.model("Gemma download completed successfully", level: .success)
            } else {
                throw MLXModelError.downloadFailed("Model files not found after download")
            }
            
        } catch is CancellationError {
            statusMessage = "Download cancelled"
            DebugLogger.model("Gemma download was cancelled", level: .warning)
            throw MLXModelError.downloadCancelled
        } catch {
            self.error = error.localizedDescription
            statusMessage = "Download failed"
            DebugLogger.model("Gemma download failed: \(error.localizedDescription)", level: .error)
            throw MLXModelError.downloadFailed(error.localizedDescription)
        }
        
        isDownloading = false
        downloadTask = nil
    }
    
    /// Cancel ongoing download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        statusMessage = "Download cancelled"
        DebugLogger.model("Download cancelled by user", level: .warning)
    }
    
    /// Delete downloaded Gemma model to free storage
    func deleteGemma() throws {
        guard isGemmaReady else {
            DebugLogger.model("Attempted to delete Gemma but it's not downloaded", level: .warning)
            return
        }
        
        do {
            try fileManager.removeItem(at: gemmaModelPath)
            isGemmaReady = false
            statusMessage = "Model deleted"
            DebugLogger.model("Gemma model deleted successfully", level: .success)
        } catch {
            DebugLogger.model("Failed to delete Gemma: \(error.localizedDescription)", level: .error)
            throw MLXModelError.deleteFailed(error.localizedDescription)
        }
    }
    
    /// Calculate storage used by MLX models
    func calculateStorageUsed() -> Int64 {
        guard fileManager.fileExists(atPath: modelsDirectory.path) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }
        
        return totalSize
    }
    
    /// Formatted storage usage string
    var storageUsedText: String {
        ByteCountFormatter.string(fromByteCount: calculateStorageUsed(), countStyle: .file)
    }
    
    /// Clear any error state
    func clearError() {
        error = nil
    }
}

// MARK: - Model Errors

enum MLXModelError: LocalizedError {
    case downloadInProgress
    case downloadFailed(String)
    case downloadCancelled
    case deleteFailed(String)
    case modelNotFound
    
    var errorDescription: String? {
        switch self {
        case .downloadInProgress:
            return "A download is already in progress"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .downloadCancelled:
            return "Download was cancelled"
        case .deleteFailed(let reason):
            return "Failed to delete model: \(reason)"
        case .modelNotFound:
            return "Model not found"
        }
    }
}
