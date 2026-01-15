//
//  CoreMLModelDownloader.swift
//  TranslateLocal
//
//  Downloads and manages CoreML translation models
//  Models must be pre-converted to CoreML format and hosted on a server
//

import Foundation
import CoreML
import ZIPFoundation

// MARK: - Model Download Info

/// Information about a downloadable model
struct DownloadableModel: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let downloadURL: String
    let sizeBytes: Int64
    let version: String
    let sourceLanguage: String
    let targetLanguage: String
    let modelType: String  // "opus" or "gemma"
    
    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// Model registry containing available models for download
struct ModelRegistryResponse: Codable {
    let models: [DownloadableModel]
    let lastUpdated: String
}

// MARK: - CoreML Model Downloader

@MainActor @Observable
class CoreMLModelDownloader {
    
    // MARK: - Observable Properties
    
    private(set) var availableModels: [DownloadableModel] = []
    private(set) var downloadedModels: Set<String> = []
    private(set) var currentDownload: DownloadableModel?
    private(set) var downloadProgress: Double = 0
    private(set) var isDownloading = false
    private(set) var error: DownloadError?
    
    // MARK: - Private Properties
    
    private let fileManager = FileManager.default
    private let modelsDirectory: URL
    private var downloadTask: URLSessionDownloadTask?
    
    // HuggingFace dataset repo for CoreML models
    private let huggingFaceRepo = "tu101/models_MLconverted"
    
    // Model registry URL
    private var registryURL: String {
        "https://huggingface.co/datasets/\(huggingFaceRepo)/resolve/main/registry.json"
    }
    
    // MARK: - Initialization
    
    init() {
        // Set up models directory - Unified with ModelManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("TranslateLocal/Models", isDirectory: true)
        
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        // Scan for already downloaded models
        scanDownloadedModels()
        
        // Load built-in model registry (fallback if network unavailable)
        loadBuiltInRegistry()
    }
    
    // MARK: - Model Registry
    
    /// Fetch the model registry from the server
    func fetchModelRegistry() async {
        guard let url = URL(string: registryURL) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let registry = try JSONDecoder().decode(ModelRegistryResponse.self, from: data)
            self.availableModels = registry.models
        } catch {
            // Use built-in registry as fallback
            print("Failed to fetch registry: \(error). Using built-in.")
        }
    }
    
    /// Load the built-in model registry (fallback when network unavailable)
    /// Models hosted at: https://huggingface.co/datasets/tu101/models_MLconverted
    private func loadBuiltInRegistry() {
        let baseURL = "https://huggingface.co/datasets/tu101/models_MLconverted/resolve/main"
        
        availableModels = [
            // Chinese ↔ English
            DownloadableModel(
                id: "opus-zh-en",
                name: "Chinese → English",
                description: "Helsinki-NLP Opus-MT model for zh-en translation",
                downloadURL: "\(baseURL)/OpusMT_zh_en.zip",
                sizeBytes: 205_296_859,
                version: "1.0.0",
                sourceLanguage: "zh",
                targetLanguage: "en",
                modelType: "opus"
            ),
            DownloadableModel(
                id: "opus-en-zh",
                name: "English → Chinese",
                description: "Helsinki-NLP Opus-MT model for en-zh translation",
                downloadURL: "\(baseURL)/OpusMT_en_zh.zip",
                sizeBytes: 205_838_546,
                version: "1.0.0",
                sourceLanguage: "en",
                targetLanguage: "zh",
                modelType: "opus"
            ),
            
            // Japanese
            DownloadableModel(
                id: "opus-en-ja",
                name: "English → Japanese",
                description: "Helsinki-NLP Opus-MT model for en-ja translation",
                downloadURL: "\(baseURL)/OpusMT_en_ja.zip",
                sizeBytes: 169_436_284,
                version: "1.0.0",
                sourceLanguage: "en",
                targetLanguage: "ja",
                modelType: "opus"
            ),
            
            // Spanish ↔ English
            DownloadableModel(
                id: "opus-es-en",
                name: "Spanish → English",
                description: "Helsinki-NLP Opus-MT model for es-en translation",
                downloadURL: "\(baseURL)/OpusMT_es_en.zip",
                sizeBytes: 204_796_283,
                version: "1.0.0",
                sourceLanguage: "es",
                targetLanguage: "en",
                modelType: "opus"
            ),
            DownloadableModel(
                id: "opus-en-es",
                name: "English → Spanish",
                description: "Helsinki-NLP Opus-MT model for en-es translation",
                downloadURL: "\(baseURL)/OpusMT_en_es.zip",
                sizeBytes: 205_293_000,
                version: "1.0.0",
                sourceLanguage: "en",
                targetLanguage: "es",
                modelType: "opus"
            ),
            
            // German ↔ English
            DownloadableModel(
                id: "opus-de-en",
                name: "German → English",
                description: "Helsinki-NLP Opus-MT model for de-en translation",
                downloadURL: "\(baseURL)/OpusMT_de_en.zip",
                sizeBytes: 191_192_950,
                version: "1.0.0",
                sourceLanguage: "de",
                targetLanguage: "en",
                modelType: "opus"
            ),
            DownloadableModel(
                id: "opus-en-de",
                name: "English → German",
                description: "Helsinki-NLP Opus-MT model for en-de translation",
                downloadURL: "\(baseURL)/OpusMT_en_de.zip",
                sizeBytes: 191_378_939,
                version: "1.0.0",
                sourceLanguage: "en",
                targetLanguage: "de",
                modelType: "opus"
            ),
            
            // French ↔ English
            DownloadableModel(
                id: "opus-fr-en",
                name: "French → English",
                description: "Helsinki-NLP Opus-MT model for fr-en translation",
                downloadURL: "\(baseURL)/OpusMT_fr_en.zip",
                sizeBytes: 194_426_148,
                version: "1.0.0",
                sourceLanguage: "fr",
                targetLanguage: "en",
                modelType: "opus"
            ),
            DownloadableModel(
                id: "opus-en-fr",
                name: "English → French",
                description: "Helsinki-NLP Opus-MT model for en-fr translation",
                downloadURL: "\(baseURL)/OpusMT_en_fr.zip",
                sizeBytes: 194_811_935,
                version: "1.0.0",
                sourceLanguage: "en",
                targetLanguage: "fr",
                modelType: "opus"
            ),
            
            // Russian ↔ English
            DownloadableModel(
                id: "opus-ru-en",
                name: "Russian → English",
                description: "Helsinki-NLP Opus-MT model for ru-en translation",
                downloadURL: "\(baseURL)/OpusMT_ru_en.zip",
                sizeBytes: 201_043_998,
                version: "1.0.0",
                sourceLanguage: "ru",
                targetLanguage: "en",
                modelType: "opus"
            ),
            DownloadableModel(
                id: "opus-en-ru",
                name: "English → Russian",
                description: "Helsinki-NLP Opus-MT model for en-ru translation",
                downloadURL: "\(baseURL)/OpusMT_en_ru.zip",
                sizeBytes: 200_996_436,
                version: "1.0.0",
                sourceLanguage: "en",
                targetLanguage: "ru",
                modelType: "opus"
            ),
            
            // Hindi ↔ English
            DownloadableModel(
                id: "opus-hi-en",
                name: "Hindi → English",
                description: "Helsinki-NLP Opus-MT model for hi-en translation",
                downloadURL: "\(baseURL)/OpusMT_hi_en.zip",
                sizeBytes: 197_834_980,
                version: "1.0.0",
                sourceLanguage: "hi",
                targetLanguage: "en",
                modelType: "opus"
            ),
            DownloadableModel(
                id: "opus-en-hi",
                name: "English → Hindi",
                description: "Helsinki-NLP Opus-MT model for en-hi translation",
                downloadURL: "\(baseURL)/OpusMT_en_hi.zip",
                sizeBytes: 199_480_410,
                version: "1.0.0",
                sourceLanguage: "en",
                targetLanguage: "hi",
                modelType: "opus"
            ),
            
            // Korean → English
            DownloadableModel(
                id: "opus-ko-en",
                name: "Korean → English",
                description: "Helsinki-NLP Opus-MT model for ko-en translation",
                downloadURL: "\(baseURL)/OpusMT_ko_en.zip",
                sizeBytes: 200_000_000,  // Estimated, update after conversion
                version: "1.0.0",
                sourceLanguage: "ko",
                targetLanguage: "en",
                modelType: "opus"
            ),
        ]
    }
    
    // MARK: - Model Scanning
    
    /// Scan for models already downloaded to device
    func scanDownloadedModels() {
        var downloaded: Set<String> = []
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        
        for url in contents {
            let modelName = url.deletingPathExtension().lastPathComponent
            downloaded.insert(modelName)
        }
        
        self.downloadedModels = downloaded
    }
    
    /// Check if a model is downloaded
    func isModelDownloaded(_ modelId: String) -> Bool {
        downloadedModels.contains(modelId)
    }
    
    /// Get the local URL for a downloaded model
    func localModelURL(for modelId: String) -> URL? {
        let modelPath = modelsDirectory.appendingPathComponent("\(modelId).mlmodelc")
        if fileManager.fileExists(atPath: modelPath.path) {
            return modelPath
        }
        
        // Try mlpackage
        let packagePath = modelsDirectory.appendingPathComponent("\(modelId).mlpackage")
        if fileManager.fileExists(atPath: packagePath.path) {
            return packagePath
        }
        
        return nil
    }
    
    // MARK: - Model Download
    
    /// Download a model from the server
    func downloadModel(_ model: DownloadableModel) async throws {
        guard !isDownloading else {
            throw DownloadError.downloadInProgress
        }
        
        guard let url = URL(string: model.downloadURL) else {
            throw DownloadError.invalidURL
        }
        
        isDownloading = true
        currentDownload = model
        downloadProgress = 0
        error = nil
        
        do {
            // Create download session with progress tracking
            let sessionConfig = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)
            
            // Download the file
            let (tempURL, response) = try await session.download(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw DownloadError.serverError
            }
            
            // Unzip if needed (models are distributed as .zip)
            let destinationURL = modelsDirectory.appendingPathComponent(model.id)
            
            if model.downloadURL.hasSuffix(".zip") {
                try await unzipModel(from: tempURL, to: destinationURL)
            } else {
                try fileManager.moveItem(at: tempURL, to: destinationURL)
            }
            
            // Update downloaded models
            downloadedModels.insert(model.id)
            
            // Ensure the ModelManager rescans immediately so Settings/Translate can load without restart.
            await ModelManager.shared.scanAvailableModels()
            
            isDownloading = false
            currentDownload = nil
            downloadProgress = 1.0
            
        } catch {
            isDownloading = false
            currentDownload = nil
            self.error = .downloadFailed(error.localizedDescription)
            throw error
        }
    }
    
    /// Unzip a downloaded model archive
    private func unzipModel(from source: URL, to destination: URL) async throws {
        // Remove existing if present
        try? fileManager.removeItem(at: destination)
        
        // Ensure destination parent exists
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        
        // Use ZIPFoundation to extract the model package
        do {
            try fileManager.unzipItem(at: source, to: destination)
            print("Successfully unzipped model to \(destination.path)")
        } catch {
            print("Failed to unzip model: \(error)")
            throw DownloadError.unzipFailed
        }
    }
    
    /// Cancel the current download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        currentDownload = nil
        downloadProgress = 0
    }
    
    // MARK: - Model Deletion
    
    /// Delete a downloaded model
    func deleteModel(_ modelId: String) throws {
        let modelPath = modelsDirectory.appendingPathComponent(modelId)
        try fileManager.removeItem(at: modelPath)
        downloadedModels.remove(modelId)
    }
    
    /// Get total storage used by downloaded models
    func totalStorageUsed() -> Int64 {
        var total: Int64 = 0
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        
        for url in contents {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        
        return total
    }
    
    // MARK: - Model Loading
    
    /// Load a CoreML model for inference
    func loadModel(_ modelId: String) async throws -> MLModel {
        guard let modelURL = localModelURL(for: modelId) else {
            throw DownloadError.modelNotFound
        }
        
        let config = MLModelConfiguration()
        config.computeUnits = .all  // Use Neural Engine when available
        
        return try await MLModel.load(contentsOf: modelURL, configuration: config)
    }
}

// MARK: - Download Error

enum DownloadError: LocalizedError {
    case downloadInProgress
    case invalidURL
    case serverError
    case downloadFailed(String)
    case modelNotFound
    case unzipFailed
    
    var errorDescription: String? {
        switch self {
        case .downloadInProgress:
            return "A download is already in progress"
        case .invalidURL:
            return "Invalid model URL"
        case .serverError:
            return "Server returned an error"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .modelNotFound:
            return "Model not found on device"
        case .unzipFailed:
            return "Failed to extract model archive"
        }
    }
}

// MARK: - Model Conversion Instructions

/*
 ================================================================================
 HOW TO CREATE AND HOST COREML MODELS
 ================================================================================
 
 The models in this app require pre-conversion to CoreML format.
 Here's how to set up model hosting:
 
 1. CONVERT MODELS (on your Mac with Python):
    
    cd MLModels
    python -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    
    # Convert Opus-MT models
    python convert_opus_to_coreml.py --model en-es --output ./converted/
    python convert_opus_to_coreml.py --model es-en --output ./converted/
    
    # Convert Gemma (requires more memory)
    python convert_gemma_to_coreml.py --output ./converted/
 
 2. PACKAGE MODELS:
    
    # Zip each model for distribution
    cd converted
    zip -r OpusMT_en_es.mlpackage.zip OpusMT_en_es.mlpackage
    zip -r OpusMT_es_en.mlpackage.zip OpusMT_es_en.mlpackage
 
 3. HOST MODELS (choose one):
    
    Option A: HuggingFace Hub (Recommended - free, fast)
    - Create account at huggingface.co
    - Create repo: translatelocal/coreml-models
    - Upload .mlpackage.zip files
    - Update URLs in this file
    
    Option B: GitHub Releases
    - Create release in your repo
    - Upload models as release assets (max 2GB each)
    - Update URLs in this file
    
    Option C: CloudFlare R2 / AWS S3
    - Upload to bucket
    - Make public or use signed URLs
    - Update URLs in this file
 
 4. CREATE REGISTRY.JSON:
    
    {
      "models": [
        {
          "id": "opus-en-es",
          "name": "English → Spanish",
          "downloadURL": "https://your-host/OpusMT_en_es.mlpackage.zip",
          "sizeBytes": 150000000,
          ...
        }
      ],
      "lastUpdated": "2026-01-10"
    }
 
 5. UPDATE THIS FILE:
    - Change registryURL to point to your registry.json
    - Update model download URLs in loadBuiltInRegistry()
 
 ================================================================================
 */
