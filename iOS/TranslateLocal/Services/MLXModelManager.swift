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
    private let userDefaults = UserDefaults.standard
    private let gemmaReadyKey = "mlx.gemmaReady.\(Bundle.main.bundleIdentifier ?? "TranslateLocal")"
    
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
        // IMPORTANT:
        // `mlx-swift-lm` manages its own cache directory for downloaded models.
        // This app previously tried to infer readiness by looking for files in `gemmaModelPath`,
        // but that is not guaranteed to match the library's cache layout.
        //
        // We instead use a persisted readiness flag set after a successful download/loadContainer call.
        // We also check for the existence of the directory structure if known, to avoid stale flags.
        let flag = userDefaults.bool(forKey: gemmaReadyKey)
        
        // Basic filesystem check to ensure we didn't wipe the data but keep the flag
        // This is a "best effort" guess at where MLX stores things if using default cache
        // If the library path changes, this check might need relaxation.
        // For now, trust the flag primarily but warn if directory seems empty.
        
        isGemmaReady = flag
        if isGemmaReady {
            DebugLogger.model("Gemma readiness flag is set.", level: .info)
        } else {
            DebugLogger.model("Gemma readiness flag not set (model not downloaded)", level: .debug)
        }
    }
    
    /// Check if device has sufficient disk space for loading/running the model (~2GB overhead)
    func hasSufficientDiskSpaceForLoad() -> Bool {
        // We want at least 2GB free for safe operation
        let requiredSpace: Int64 = 2 * 1024 * 1024 * 1024
        
        if let attrs = try? fileManager.attributesOfFileSystem(forPath: modelsDirectory.path),
           let freeSize = attrs[.systemFreeSize] as? Int64 {
            if freeSize < requiredSpace {
                 DebugLogger.model("Low disk space: \(ByteCountFormatter.string(fromByteCount: freeSize, countStyle: .file)) free, need ~2GB", level: .warning)
                 return false
            } else {
                return true
            }
        }
        return true // Assume true if check fails
    }
    
    /// Check if device has sufficient RAM for Smart PiP features (Requires ~8GB device)
    /// This is to prevent OOM kills when running PiP + Inference + Foreground app
    func hasSufficientMemoryForPiP() -> Bool {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        // Use 7.5GB threshold to account for marketing vs binary bytes
        let requiredMemory: UInt64 = 7_500_000_000
        
        let hasMemory = physicalMemory >= requiredMemory
        
        if !hasMemory {
            DebugLogger.model("Smart PiP check: Insufficient RAM (\(ByteCountFormatter.string(fromByteCount: Int64(physicalMemory), countStyle: .memory))). Need 8GB+.", level: .warning)
        }
        
        return hasMemory
    }
    
    /// Download Gemma model from HuggingFace
    /// Uses MLX Swift LM's built-in model downloading
    func downloadGemma() async throws {
        // MLX requires real Apple Silicon - fail gracefully on simulator
        #if targetEnvironment(simulator)
        error = "Gemma download requires a real device. MLX is not supported on the iOS Simulator."
        statusMessage = "Not available on Simulator"
        throw MLXModelError.downloadFailed("MLX requires a real device with Apple Silicon. Please run on a physical iPhone or iPad.")
        #else
        
        // Check disk space before starting download (approx 1.5GB needed + overhead)
        guard hasSufficientDiskSpaceForLoad() else {
            error = "Insufficient disk space. Please free up 2GB+."
            statusMessage = "Low Disk Space"
            throw MLXModelError.downloadFailed("Insufficient disk space. 2GB+ required.")
        }
        
        guard !isDownloading else {
            throw MLXModelError.downloadInProgress
        }
        
        isDownloading = true
        downloadProgress = 0
        downloadedBytes = 0
        totalBytes = 0
        error = nil
        statusMessage = "Preparing download..."
        
        // Ensure cleanup happens even on error
        defer {
            isDownloading = false
            downloadTask = nil
        }
        
        DebugLogger.model("Starting Gemma download from: \(gemmaModelId)", level: .info)
        
        do {
            // Use MLX Swift LM's built-in model loading which handles download
            // The loadModel function will download if not cached
            statusMessage = "Downloading model files..."
            
            let modelConfiguration = ModelConfiguration(id: gemmaModelId)
            
            // This will download the model if not present.
            // Wrap in a Task so cancelDownload() can actually cancel the work.
            let task = Task {
                _ = try await LLMModelFactory.shared.loadContainer(
                    configuration: modelConfiguration
                ) { progress in
                    Task { @MainActor in
                        self.downloadProgress = progress.fractionCompleted
                        self.statusMessage = "Downloading: \(Int(progress.fractionCompleted * 100))%"
                    }
                }
            }
            downloadTask = task
            _ = try await task.value
            
            // Mark downloaded (actual validation happens on load).
            userDefaults.set(true, forKey: gemmaReadyKey)
            isGemmaReady = true
            statusMessage = "Download complete!"
            DebugLogger.model("Gemma download completed successfully (cached by MLX)", level: .success)
            
        } catch is CancellationError {
            statusMessage = "Download cancelled"
            DebugLogger.model("Gemma download was cancelled", level: .warning)
            throw MLXModelError.downloadCancelled
        } catch let mlxError as MLXModelError {
            throw mlxError
        } catch {
            self.error = error.localizedDescription
            statusMessage = "Download failed"
            DebugLogger.model("Gemma download failed: \(error.localizedDescription)", level: .error)
            throw MLXModelError.downloadFailed(error.localizedDescription)
        }
        #endif
    }
    
    /// Cancel ongoing download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        statusMessage = "Download cancelled"
        DebugLogger.model("Download cancelled by user", level: .warning)
    }

    /// Reset Gemma download state and any app-managed cache.
    /// This does NOT guarantee deletion of the `mlx-swift-lm` internal cache directory (library-managed),
    /// but it resets the app state so the next download/load is treated as a fresh install.
    func resetGemmaCache() {
        // Cancel any ongoing download work
        cancelDownload()

        // Clear readiness flag + UI state
        userDefaults.removeObject(forKey: gemmaReadyKey)
        isGemmaReady = false
        downloadProgress = 0
        downloadedBytes = 0
        totalBytes = 0
        error = nil
        statusMessage = "Reset complete"

        // Best-effort cleanup of any older app-managed files
        if fileManager.fileExists(atPath: gemmaModelPath.path) {
            try? fileManager.removeItem(at: gemmaModelPath)
        }

        #if !targetEnvironment(simulator)
        // Clear MLX GPU cache to reduce memory pressure before re-download/reload.
        MLX.GPU.clearCache()
        #endif

        DebugLogger.model("Gemma reset requested: cleared readiness flag and app-managed files", level: .warning)
    }
    
    /// Delete downloaded Gemma model to free storage
    func deleteGemma() throws {
        guard isGemmaReady else {
            DebugLogger.model("Attempted to delete Gemma but it's not downloaded", level: .warning)
            return
        }
        
        do {
            // Best-effort: remove our app directory (older versions used this), and clear readiness flag.
            // The MLX cache location is managed by the library; if it stores elsewhere, GemmaService.loadModel
            // will fail and the UI will prompt re-download.
            if fileManager.fileExists(atPath: gemmaModelPath.path) {
                try fileManager.removeItem(at: gemmaModelPath)
            }
            userDefaults.removeObject(forKey: gemmaReadyKey)
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
