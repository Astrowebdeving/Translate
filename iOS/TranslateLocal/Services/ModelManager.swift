//
//  ModelManager.swift
//  TranslateLocal
//
//  Manages loading, caching, and lifecycle of ML models
//

import Foundation
import CoreML
import Combine

// MARK: - Model Info

/// Information about an available model
struct ModelInfo: Identifiable, Codable {
    let id: String
    let type: String
    let displayName: String
    let version: String
    let sizeBytes: Int64
    let isBundled: Bool
    let downloadURL: URL?
    let sourceLanguages: [String]
    let targetLanguages: [String]
    var isDownloaded: Bool = false
    
    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }
}

/// Remote model registry for downloadable models
struct ModelRegistry {
    // HuggingFace Hub URLs for Opus-MT models (these are the real HF repo URLs)
    static let modelDownloadURLs: [TranslationModelType: String] = [
        // Spanish ↔ English
        .opusEnEs: "https://huggingface.co/Helsinki-NLP/opus-mt-en-es/resolve/main/pytorch_model.bin",
        .opusEsEn: "https://huggingface.co/Helsinki-NLP/opus-mt-es-en/resolve/main/pytorch_model.bin",
        // Chinese ↔ English
        .opusEnZh: "https://huggingface.co/Helsinki-NLP/opus-mt-en-zh/resolve/main/pytorch_model.bin",
        .opusZhEn: "https://huggingface.co/Helsinki-NLP/opus-mt-zh-en/resolve/main/pytorch_model.bin",
        // Japanese ↔ English
        .opusEnJa: "https://huggingface.co/Helsinki-NLP/opus-mt-en-jap/resolve/main/pytorch_model.bin",
        .opusJaEn: "https://huggingface.co/Helsinki-NLP/opus-mt-jap-en/resolve/main/pytorch_model.bin",
    ]
    
    static func downloadURL(for model: TranslationModelType) -> URL? {
        guard let urlString = modelDownloadURLs[model] else { return nil }
        return URL(string: urlString)
    }
}

/// Model download progress
struct ModelDownloadProgress {
    let modelType: TranslationModelType
    let bytesDownloaded: Int64
    let totalBytes: Int64
    let progress: Double
    
    var progressFormatted: String {
        return String(format: "%.1f%%", progress * 100)
    }
}

// MARK: - Model Manager

/// Singleton manager for ML model lifecycle
@MainActor @Observable
class ModelManager {
    
    // MARK: - Singleton
    
    static let shared = ModelManager()
    
    // MARK: - Observable Properties
    
    private(set) var availableModels: [TranslationModelType: ModelInfo] = [:]
    private(set) var loadedModels: Set<TranslationModelType> = []
    private(set) var downloadProgress: ModelDownloadProgress?
    private(set) var isDownloading = false
    private(set) var error: ModelManagerError?
    
    // MARK: - Private Properties
    
    private var modelCache: [TranslationModelType: MLModel] = [:]
    private let fileManager = FileManager.default
    private let modelDirectory: URL
    private var downloadTask: URLSessionDownloadTask?
    
    // MARK: - Initialization
    
    private init() {
        // Set up model directory in app support
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelDirectory = appSupport.appendingPathComponent("TranslateLocal/Models", isDirectory: true)
        
        // Create directory if needed
        try? fileManager.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        
        // Scan for available models
        Task {
            await scanAvailableModels()
        }
    }
    
    // MARK: - Model Discovery
    
    /// Scan for bundled and downloaded models
    func scanAvailableModels() async {
        var models: [TranslationModelType: ModelInfo] = [:]
        
        // Check bundled models
        for type in TranslationModelType.allCases {
            if let bundledURL = Bundle.main.url(forResource: type.rawValue, withExtension: "mlmodelc") {
                let info = createModelInfo(for: type, at: bundledURL, isBundled: true)
                models[type] = info
            } else if let bundledURL = Bundle.main.url(forResource: type.rawValue, withExtension: "mlpackage") {
                let info = createModelInfo(for: type, at: bundledURL, isBundled: true)
                models[type] = info
            }
            
            // Check downloaded models
            let downloadedURL = modelDirectory.appendingPathComponent("\(type.rawValue).mlmodelc")
            if fileManager.fileExists(atPath: downloadedURL.path) {
                let info = createModelInfo(for: type, at: downloadedURL, isBundled: false)
                models[type] = info
            }
        }
        
        self.availableModels = models
    }
    
    private func createModelInfo(for type: TranslationModelType, at url: URL, isBundled: Bool) -> ModelInfo {
        // Get file size
        let size: Int64
        if let attrs = try? fileManager.attributesOfItem(atPath: url.path),
           let fileSize = attrs[.size] as? Int64 {
            size = fileSize
        } else {
            // Calculate directory size for mlpackage/mlmodelc
            size = calculateDirectorySize(at: url)
        }
        
        return ModelInfo(
            id: type.rawValue,
            type: type == .gemma3n ? "causal_lm" : "encoder_decoder",
            displayName: type.displayName,
            version: "1.0.0",
            sizeBytes: size,
            isBundled: isBundled,
            downloadURL: nil,  // Would be set from remote config
            sourceLanguages: type.sourceLanguage.map { [$0.id] } ?? ["*"],
            targetLanguages: type.targetLanguage.map { [$0.id] } ?? ["*"]
        )
    }
    
    private func calculateDirectorySize(at url: URL) -> Int64 {
        var size: Int64 = 0
        
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = attrs.fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        
        return size
    }
    
    // MARK: - Model Loading
    
    /// Check if a model is available (bundled or downloaded)
    func isModelAvailable(_ type: TranslationModelType) -> Bool {
        return availableModels[type] != nil
    }
    
    /// Check if a model is currently loaded in memory
    func isModelLoaded(_ type: TranslationModelType) -> Bool {
        return loadedModels.contains(type)
    }
    
    /// Load a model into memory
    func loadModel(_ type: TranslationModelType) async throws -> MLModel {
        // Check cache first
        if let cached = modelCache[type] {
            return cached
        }
        
        // Find model URL
        guard let modelURL = findModelURL(for: type) else {
            throw ModelManagerError.modelNotFound(type.rawValue)
        }
        
        do {
            // Configure for optimal performance
            let config = MLModelConfiguration()
            config.computeUnits = .all  // Use Neural Engine when available
            
            // Load model
            let model = try await MLModel.load(contentsOf: modelURL, configuration: config)
            
            // Cache and track
            modelCache[type] = model
            loadedModels.insert(type)
            
            return model
            
        } catch {
            throw ModelManagerError.loadFailed(type.rawValue, error.localizedDescription)
        }
    }
    
    /// Unload a model from memory
    func unloadModel(_ type: TranslationModelType) {
        modelCache.removeValue(forKey: type)
        loadedModels.remove(type)
    }
    
    /// Unload all models to free memory
    func unloadAllModels() {
        modelCache.removeAll()
        loadedModels.removeAll()
    }
    
    private func findModelURL(for type: TranslationModelType) -> URL? {
        // Check bundled first (compiled .mlmodelc)
        if let url = Bundle.main.url(forResource: type.rawValue, withExtension: "mlmodelc") {
            return url
        }
        
        // Check bundled .mlpackage
        if let url = Bundle.main.url(forResource: type.rawValue, withExtension: "mlpackage") {
            return url
        }
        
        // Check downloaded models
        let downloadedURL = modelDirectory.appendingPathComponent("\(type.rawValue).mlmodelc")
        if fileManager.fileExists(atPath: downloadedURL.path) {
            return downloadedURL
        }
        
        return nil
    }
    
    // MARK: - Model Download
    
    /// Download a model from remote server
    func downloadModel(_ type: TranslationModelType, from url: URL) async throws {
        guard !isDownloading else {
            throw ModelManagerError.downloadInProgress
        }
        
        isDownloading = true
        error = nil
        
        do {
            let (localURL, _) = try await URLSession.shared.download(from: url, delegate: DownloadDelegate { [weak self] progress in
                Task { @MainActor in
                    self?.downloadProgress = ModelDownloadProgress(
                        modelType: type,
                        bytesDownloaded: Int64(progress.completedUnitCount),
                        totalBytes: Int64(progress.totalUnitCount),
                        progress: progress.fractionCompleted
                    )
                }
            })
            
            // Move to models directory
            let destinationURL = modelDirectory.appendingPathComponent("\(type.rawValue).mlmodelc")
            
            // Remove existing if present
            try? fileManager.removeItem(at: destinationURL)
            
            // Move downloaded file
            try fileManager.moveItem(at: localURL, to: destinationURL)
            
            // Refresh available models
            await scanAvailableModels()
            
            isDownloading = false
            downloadProgress = nil
            
        } catch {
            isDownloading = false
            downloadProgress = nil
            throw ModelManagerError.downloadFailed(error.localizedDescription)
        }
    }
    
    /// Cancel ongoing download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        downloadProgress = nil
    }
    
    // MARK: - Model Deletion
    
    /// Delete a downloaded model
    func deleteModel(_ type: TranslationModelType) throws {
        // Only allow deleting non-bundled models
        guard availableModels[type]?.isBundled == false else {
            throw ModelManagerError.cannotDeleteBundled
        }
        
        // Unload if loaded
        unloadModel(type)
        
        // Delete from disk
        let modelURL = modelDirectory.appendingPathComponent("\(type.rawValue).mlmodelc")
        try fileManager.removeItem(at: modelURL)
        
        // Update available models
        Task {
            await scanAvailableModels()
        }
    }
    
    // MARK: - Memory Management
    
    /// Get current memory usage of loaded models
    func getMemoryUsage() -> Int64 {
        var totalSize: Int64 = 0
        
        for type in loadedModels {
            if let info = availableModels[type] {
                totalSize += info.sizeBytes
            }
        }
        
        return totalSize
    }
    
    /// Optimize memory by unloading least recently used models
    func optimizeMemory(targetBytes: Int64) {
        var currentUsage = getMemoryUsage()
        
        // Simple strategy: unload models until under target
        // A more sophisticated implementation would track usage patterns
        for type in loadedModels {
            if currentUsage <= targetBytes {
                break
            }
            
            if let info = availableModels[type] {
                unloadModel(type)
                currentUsage -= info.sizeBytes
            }
        }
    }
}

// MARK: - Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let progressHandler: (Progress) -> Void
    
    init(progressHandler: @escaping (Progress) -> Void) {
        self.progressHandler = progressHandler
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Progress(totalUnitCount: totalBytesExpectedToWrite)
        progress.completedUnitCount = totalBytesWritten
        progressHandler(progress)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in the async download call
    }
}

// MARK: - Error Types

enum ModelManagerError: LocalizedError {
    case modelNotFound(String)
    case loadFailed(String, String)
    case downloadInProgress
    case downloadFailed(String)
    case cannotDeleteBundled
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model '\(name)' not found"
        case .loadFailed(let name, let reason):
            return "Failed to load '\(name)': \(reason)"
        case .downloadInProgress:
            return "A download is already in progress"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .cannotDeleteBundled:
            return "Cannot delete bundled models"
        }
    }
}
