//
//  ModelDownloadView.swift
//  TranslateLocal
//
//  View for downloading and managing translation models
//

import SwiftUI
import ZIPFoundation

struct ModelDownloadView: View {
    @Environment(AppState.self) var appState
    @StateObject private var downloader = ModelDownloadManager()
    
    var body: some View {
        List {
            // Status Section
            Section {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Translation Models")
                            .font(.headline)
                        Text("Download models to enable offline translation")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if downloader.isDownloading {
                        ProgressView()
                    }
                }
            }
            
            // Downloaded Models
            if !downloader.downloadedModels.isEmpty {
                Section("Downloaded") {
                    ForEach(downloader.downloadedModels, id: \.id) { model in
                        DownloadedModelRow(model: model) {
                            downloader.deleteModel(model)
                        }
                    }
                }
            }
            
            // Gemma 3n (MLX) Section
            Section {
                GemmaDownloadRow()
            } header: {
                Text("Gemma 3n (Multilingual AI)")
            } footer: {
                Text("Gemma 3n supports all language pairs in a single model. Powered by MLX for on-device inference.")
            }
            
            // Available Models
            Section("Available for Download") {
                ForEach(downloader.availableModels, id: \.id) { model in
                    if !downloader.isDownloaded(model.id) {
                        AvailableModelRow(
                            model: model,
                            isDownloading: downloader.currentDownloadId == model.id,
                            progress: downloader.downloadProgress
                        ) {
                            Task {
                                await downloader.downloadModel(model)
                            }
                        }
                    }
                }
            }
            
            // Info Section
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Models are stored locally on your device", systemImage: "iphone")
                    Label("No internet required after download", systemImage: "wifi.slash")
                    Label("All processing happens on-device", systemImage: "lock.shield")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            // Storage Info
            Section("Storage") {
                HStack {
                    Text("Opus-MT models")
                    Spacer()
                    Text(downloader.storageUsedFormatted)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("MLX models (Gemma)")
                    Spacer()
                    Text(MLXModelManager.shared.storageUsedText)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Models")
        .onAppear {
            downloader.refresh()
        }
        .alert("Download Error", isPresented: .constant(downloader.error != nil)) {
            Button("OK") { downloader.clearError() }
        } message: {
            Text(downloader.error ?? "Unknown error")
        }
    }
}

// MARK: - Gemma Download Row

struct GemmaDownloadRow: View {
    @State private var mlxManager = MLXModelManager.shared
    @State private var showDeleteConfirmation = false
    @State private var showResetConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gemma 3n E2B")
                        .font(.headline)
                    Text("Any language pair • Smart translation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if mlxManager.isDownloading {
                    VStack(alignment: .trailing, spacing: 4) {
                        ProgressView(value: mlxManager.downloadProgress)
                            .frame(width: 60)
                        Text(mlxManager.progressText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else if mlxManager.isGemmaReady {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                } else {
                    Button {
                        Task {
                            try? await mlxManager.downloadGemma()
                        }
                    } label: {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.title2)
                            .foregroundColor(.indigo)
                    }
                }
            }
            
            if mlxManager.isGemmaReady {
                HStack {
                    Text(mlxManager.estimatedSizeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        showResetConfirmation = true
                    } label: {
                        Text("Reset & Re-download")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text("Delete")
                            .font(.caption)
                    }
                }
            } else if !mlxManager.isDownloading {
                Text("~\(mlxManager.estimatedSizeText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !mlxManager.statusMessage.isEmpty && (mlxManager.isDownloading || mlxManager.error != nil) {
                Text(mlxManager.statusMessage)
                    .font(.caption2)
                    .foregroundColor(mlxManager.error != nil ? .red : .secondary)
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog("Reset Gemma Cache?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Reset & Re-download", role: .destructive) {
                Task {
                    // Unload to prevent holding GPU memory while resetting
                    GemmaService.shared.unloadModel()
                    mlxManager.resetGemmaCache()
                    try? await mlxManager.downloadGemma()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset Gemma's download state and attempt a fresh download. It may still take significant storage (~\(mlxManager.estimatedSizeText)).")
        }
        .confirmationDialog("Delete Gemma Model?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                try? mlxManager.deleteGemma()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will free up ~\(mlxManager.estimatedSizeText) of storage. You can download it again later.")
        }
    }
}

// MARK: - Model Row Views

struct DownloadedModelRow: View {
    let model: DownloadableModelInfo
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.body)
                HStack(spacing: 8) {
                    Text(model.languagePair)
                        .font(.caption)
                        .foregroundColor(.indigo)
                    Text(model.sizeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AvailableModelRow: View {
    let model: DownloadableModelInfo
    let isDownloading: Bool
    let progress: Double
    let onDownload: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.body)
                HStack(spacing: 8) {
                    Text(model.languagePair)
                        .font(.caption)
                        .foregroundColor(.indigo)
                    Text(model.sizeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isDownloading {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: progress)
                        .frame(width: 60)
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Button {
                    onDownload()
                } label: {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.title3)
                        .foregroundColor(.indigo)
                }
            }
        }
    }
}

// MARK: - Model Download Manager

@MainActor
class ModelDownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var availableModels: [DownloadableModelInfo] = []
    @Published var downloadedModels: [DownloadableModelInfo] = []
    @Published var isDownloading = false
    @Published var currentDownloadId: String?
    @Published var downloadProgress: Double = 0
    @Published var error: String?
    @Published var storageUsed: Int64 = 0
    
    private let fileManager = FileManager.default
    private let modelsDirectory: URL
    private var downloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession?
    private var currentModel: DownloadableModelInfo?
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    
    // HuggingFace dataset repo
    private let baseURL = "https://huggingface.co/datasets/tu101/models_MLconverted/resolve/main"
    
    var storageUsedFormatted: String {
        ByteCountFormatter.string(fromByteCount: storageUsed, countStyle: .file)
    }
    
    override init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("TranslateLocal/Models", isDirectory: true)
        
        super.init()
        
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        // Create URL session with delegate for progress tracking
        let config = URLSessionConfiguration.default
        downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        
        loadAvailableModels()
        scanDownloadedModels()
    }
    
    func refresh() {
        scanDownloadedModels()
        calculateStorageUsed()
    }
    
    func isDownloaded(_ modelId: String) -> Bool {
        downloadedModels.contains { $0.id == modelId }
    }
    
    private func loadAvailableModels() {
        // Models available from https://huggingface.co/datasets/tu101/models_MLconverted
        availableModels = [
            // Chinese ↔ English
            DownloadableModelInfo(
                id: "opus-zh-en",
                displayName: "Chinese → English",
                languagePair: "ZH → EN",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 205_296_859,
                downloadURL: "\(baseURL)/OpusMT_zh_en.zip"
            ),
            DownloadableModelInfo(
                id: "opus-en-zh",
                displayName: "English → Chinese",
                languagePair: "EN → ZH",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 205_838_546,
                downloadURL: "\(baseURL)/OpusMT_en_zh.zip"
            ),
            
            // Japanese
            DownloadableModelInfo(
                id: "opus-en-ja",
                displayName: "English → Japanese",
                languagePair: "EN → JA",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 169_436_284,
                downloadURL: "\(baseURL)/OpusMT_en_ja.zip"
            ),
            
            // Spanish ↔ English
            DownloadableModelInfo(
                id: "opus-es-en",
                displayName: "Spanish → English",
                languagePair: "ES → EN",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 204_796_283,
                downloadURL: "\(baseURL)/OpusMT_es_en.zip"
            ),
            DownloadableModelInfo(
                id: "opus-en-es",
                displayName: "English → Spanish",
                languagePair: "EN → ES",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 205_293_000,
                downloadURL: "\(baseURL)/OpusMT_en_es.zip"
            ),
            
            // German ↔ English
            DownloadableModelInfo(
                id: "opus-de-en",
                displayName: "German → English",
                languagePair: "DE → EN",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 191_192_950,
                downloadURL: "\(baseURL)/OpusMT_de_en.zip"
            ),
            DownloadableModelInfo(
                id: "opus-en-de",
                displayName: "English → German",
                languagePair: "EN → DE",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 191_378_939,
                downloadURL: "\(baseURL)/OpusMT_en_de.zip"
            ),
            
            // French ↔ English
            DownloadableModelInfo(
                id: "opus-fr-en",
                displayName: "French → English",
                languagePair: "FR → EN",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 194_426_148,
                downloadURL: "\(baseURL)/OpusMT_fr_en.zip"
            ),
            DownloadableModelInfo(
                id: "opus-en-fr",
                displayName: "English → French",
                languagePair: "EN → FR",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 194_811_935,
                downloadURL: "\(baseURL)/OpusMT_en_fr.zip"
            ),
            
            // Russian ↔ English
            DownloadableModelInfo(
                id: "opus-ru-en",
                displayName: "Russian → English",
                languagePair: "RU → EN",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 201_043_998,
                downloadURL: "\(baseURL)/OpusMT_ru_en.zip"
            ),
            DownloadableModelInfo(
                id: "opus-en-ru",
                displayName: "English → Russian",
                languagePair: "EN → RU",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 200_996_436,
                downloadURL: "\(baseURL)/OpusMT_en_ru.zip"
            ),
            
            // Hindi ↔ English
            DownloadableModelInfo(
                id: "opus-hi-en",
                displayName: "Hindi → English",
                languagePair: "HI → EN",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 197_834_980,
                downloadURL: "\(baseURL)/OpusMT_hi_en.zip"
            ),
            DownloadableModelInfo(
                id: "opus-en-hi",
                displayName: "English → Hindi",
                languagePair: "EN → HI",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 199_480_410,
                downloadURL: "\(baseURL)/OpusMT_en_hi.zip"
            ),
            
            // Korean → English
            DownloadableModelInfo(
                id: "opus-ko-en",
                displayName: "Korean → English",
                languagePair: "KO → EN",
                description: "Helsinki-NLP Opus-MT model",
                sizeBytes: 200_000_000,  // Estimated, update after conversion
                downloadURL: "\(baseURL)/OpusMT_ko_en.zip"
            ),
        ]
    }
    
    private func scanDownloadedModels() {
        var downloaded: [DownloadableModelInfo] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: modelsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return }
        
        for url in contents {
            // Get model ID from folder name (e.g., "opus-zh-en" from "opus-zh-en/")
            let modelId = url.lastPathComponent
            if let model = availableModels.first(where: { $0.id == modelId }) {
                downloaded.append(model)
            }
        }
        
        self.downloadedModels = downloaded
    }
    
    private func calculateStorageUsed() {
        var total: Int64 = 0
        
        guard let enumerator = fileManager.enumerator(
            at: modelsDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return }
        
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        
        storageUsed = total
    }
    
    func downloadModel(_ model: DownloadableModelInfo) async {
        guard !isDownloading else { return }
        guard let url = URL(string: model.downloadURL) else {
            error = "Invalid download URL"
            return
        }
        
        isDownloading = true
        currentDownloadId = model.id
        currentModel = model
        downloadProgress = 0
        error = nil
        
        DebugLogger.info("Starting download for \(model.displayName) from \(model.downloadURL)", category: .model)
        
        do {
            // Download the zip file with progress tracking
            let tempURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                self.downloadContinuation = continuation
                self.downloadTask = self.downloadSession?.downloadTask(with: url)
                self.downloadTask?.resume()
            }
            
            // Unzip the model
            let modelDirectory = modelsDirectory.appendingPathComponent(model.id)
            try await unzipModel(from: tempURL, to: modelDirectory)
            
            // Clean up temp file
            try? fileManager.removeItem(at: tempURL)
            
            DebugLogger.success("Download complete for \(model.displayName)", category: .model)
            
            isDownloading = false
            currentDownloadId = nil
            currentModel = nil
            downloadProgress = 1.0
            
            refresh()
            
            // Make newly downloaded models visible to the rest of the app immediately (no restart needed).
            await ModelManager.shared.scanAvailableModels()
            
        } catch {
            DebugLogger.error("Download failed for \(model.displayName): \(error)", category: .model)
            
            isDownloading = false
            currentDownloadId = nil
            currentModel = nil
            self.error = "Download failed: \(error.localizedDescription)"
        }
    }
    
    private func unzipModel(from source: URL, to destination: URL) async throws {
        // Remove existing if present
        try? fileManager.removeItem(at: destination)
        
        // Create destination directory
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        
        // Unzip using ZIPFoundation
        try fileManager.unzipItem(at: source, to: destination)
        
        DebugLogger.info("Unzipped model to \(destination.path)", category: .model)
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        currentDownloadId = nil
        currentModel = nil
        downloadProgress = 0
        downloadContinuation?.resume(throwing: CancellationError())
        downloadContinuation = nil
    }
    
    func deleteModel(_ model: DownloadableModelInfo) {
        let modelPath = modelsDirectory.appendingPathComponent(model.id)
        try? fileManager.removeItem(at: modelPath)
        
        DebugLogger.info("Deleted model \(model.displayName)", category: .model)
        refresh()
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.downloadProgress = progress
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Move to a persistent temp location before the delegate method returns
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        do {
            try FileManager.default.moveItem(at: location, to: tempURL)
            Task { @MainActor in
                self.downloadContinuation?.resume(returning: tempURL)
                self.downloadContinuation = nil
            }
        } catch {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: error)
                self.downloadContinuation = nil
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: error)
                self.downloadContinuation = nil
            }
        }
    }
}

// MARK: - Model Info

struct DownloadableModelInfo: Identifiable {
    let id: String
    let displayName: String
    let languagePair: String
    let description: String
    let sizeBytes: Int64
    let downloadURL: String
    
    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ModelDownloadView()
            .environment(AppState())
    }
}
