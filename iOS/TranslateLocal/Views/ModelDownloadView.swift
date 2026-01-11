//
//  ModelDownloadView.swift
//  TranslateLocal
//
//  View for downloading and managing translation models
//

import SwiftUI

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
                    Text("Used by models")
                    Spacer()
                    Text(downloader.storageUsedFormatted)
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
class ModelDownloadManager: ObservableObject {
    @Published var availableModels: [DownloadableModelInfo] = []
    @Published var downloadedModels: [DownloadableModelInfo] = []
    @Published var isDownloading = false
    @Published var currentDownloadId: String?
    @Published var downloadProgress: Double = 0
    @Published var error: String?
    @Published var storageUsed: Int64 = 0
    
    private let fileManager = FileManager.default
    private let modelsDirectory: URL
    
    var storageUsedFormatted: String {
        ByteCountFormatter.string(fromByteCount: storageUsed, countStyle: .file)
    }
    
    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        modelsDirectory = appSupport.appendingPathComponent("TranslateLocal/Models", isDirectory: true)
        try? fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
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
        // These models need to be pre-converted to CoreML format and hosted
        // For now, we provide information about what would be available
        availableModels = [
            DownloadableModelInfo(
                id: "opus-zh-en",
                displayName: "Chinese → English",
                languagePair: "ZH → EN",
                description: "Helsinki-NLP Opus-MT model",
                estimatedSizeMB: 180,
                huggingFaceId: "Helsinki-NLP/opus-mt-zh-en"
            ),
            DownloadableModelInfo(
                id: "opus-en-zh",
                displayName: "English → Chinese",
                languagePair: "EN → ZH",
                description: "Helsinki-NLP Opus-MT model",
                estimatedSizeMB: 180,
                huggingFaceId: "Helsinki-NLP/opus-mt-en-zh"
            ),
            DownloadableModelInfo(
                id: "opus-ja-en",
                displayName: "Japanese → English",
                languagePair: "JA → EN",
                description: "Helsinki-NLP Opus-MT model",
                estimatedSizeMB: 180,
                huggingFaceId: "Helsinki-NLP/opus-mt-ja-en"
            ),
            DownloadableModelInfo(
                id: "opus-en-ja",
                displayName: "English → Japanese",
                languagePair: "EN → JA",
                description: "Helsinki-NLP Opus-MT model",
                estimatedSizeMB: 180,
                huggingFaceId: "Helsinki-NLP/opus-mt-en-ja"
            ),
            DownloadableModelInfo(
                id: "opus-es-en",
                displayName: "Spanish → English",
                languagePair: "ES → EN",
                description: "Helsinki-NLP Opus-MT model",
                estimatedSizeMB: 150,
                huggingFaceId: "Helsinki-NLP/opus-mt-es-en"
            ),
            DownloadableModelInfo(
                id: "opus-en-es",
                displayName: "English → Spanish",
                languagePair: "EN → ES",
                description: "Helsinki-NLP Opus-MT model",
                estimatedSizeMB: 150,
                huggingFaceId: "Helsinki-NLP/opus-mt-en-es"
            ),
            DownloadableModelInfo(
                id: "opus-fr-en",
                displayName: "French → English",
                languagePair: "FR → EN",
                description: "Helsinki-NLP Opus-MT model",
                estimatedSizeMB: 150,
                huggingFaceId: "Helsinki-NLP/opus-mt-fr-en"
            ),
            DownloadableModelInfo(
                id: "opus-en-fr",
                displayName: "English → French",
                languagePair: "EN → FR",
                description: "Helsinki-NLP Opus-MT model",
                estimatedSizeMB: 150,
                huggingFaceId: "Helsinki-NLP/opus-mt-en-fr"
            ),
            DownloadableModelInfo(
                id: "opus-de-en",
                displayName: "German → English",
                languagePair: "DE → EN",
                description: "Helsinki-NLP Opus-MT model",
                estimatedSizeMB: 150,
                huggingFaceId: "Helsinki-NLP/opus-mt-de-en"
            ),
            DownloadableModelInfo(
                id: "opus-en-de",
                displayName: "English → German",
                languagePair: "EN → DE",
                description: "Helsinki-NLP Opus-MT model",
                estimatedSizeMB: 150,
                huggingFaceId: "Helsinki-NLP/opus-mt-en-de"
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
            let modelId = url.deletingPathExtension().lastPathComponent
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
        
        isDownloading = true
        currentDownloadId = model.id
        downloadProgress = 0
        error = nil
        
        DebugLogger.info("Starting download for \(model.displayName)", category: .model)
        
        // Note: In a real implementation, you would download pre-converted CoreML models
        // from your own hosting (HuggingFace, GitHub Releases, S3, etc.)
        // 
        // The Opus-MT models on HuggingFace are in PyTorch format and need conversion.
        // For a production app, you would:
        // 1. Convert models to CoreML format using coremltools
        // 2. Host the .mlpackage files on your server
        // 3. Download and extract them here
        
        // Simulate download for demo (replace with real download)
        for i in 0...10 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            downloadProgress = Double(i) / 10.0
        }
        
        // Create a placeholder file to mark as "downloaded"
        let modelPath = modelsDirectory.appendingPathComponent("\(model.id).placeholder")
        try? "Demo model placeholder - replace with real CoreML model".write(to: modelPath, atomically: true, encoding: .utf8)
        
        DebugLogger.success("Download complete for \(model.displayName)", category: .model)
        
        isDownloading = false
        currentDownloadId = nil
        
        // Show info about real implementation
        error = "Demo mode: To enable real translation, you need to:\n1. Convert Opus-MT models to CoreML format\n2. Host them on your server\n3. Update the download URLs in the app\n\nSee MLModels/ folder for conversion scripts."
        
        refresh()
    }
    
    func deleteModel(_ model: DownloadableModelInfo) {
        let modelPath = modelsDirectory.appendingPathComponent("\(model.id).placeholder")
        try? fileManager.removeItem(at: modelPath)
        
        // Also try deleting actual model formats
        let mlmodelcPath = modelsDirectory.appendingPathComponent("\(model.id).mlmodelc")
        try? fileManager.removeItem(at: mlmodelcPath)
        
        let mlpackagePath = modelsDirectory.appendingPathComponent("\(model.id).mlpackage")
        try? fileManager.removeItem(at: mlpackagePath)
        
        DebugLogger.info("Deleted model \(model.displayName)", category: .model)
        refresh()
    }
    
    func clearError() {
        error = nil
    }
}

// MARK: - Model Info

struct DownloadableModelInfo: Identifiable {
    let id: String
    let displayName: String
    let languagePair: String
    let description: String
    let estimatedSizeMB: Int
    let huggingFaceId: String
    
    var sizeFormatted: String {
        "\(estimatedSizeMB) MB"
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ModelDownloadView()
            .environment(AppState())
    }
}
