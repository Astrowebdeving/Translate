//
//  ImageTranslateView.swift
//  TranslateLocal
//
//  Translate text from images (screenshots, photos)
//

import SwiftUI
import PhotosUI

struct ImageTranslateView: View {
    @Environment(AppState.self) var appState
    
    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var recognizedBlocks: [RecognizedTextBlock] = []
    @State private var translatedTexts: [UUID: String] = [:]
    @State private var fullTranslation: String = ""
    @State private var isProcessing = false
    @State private var showingCamera = false
    @State private var viewMode: ViewMode = .overlay
    
    // Error and debug feedback
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDebugInfo = false
    @State private var processingStatus = ""
    
    enum ViewMode: String, CaseIterable {
        case overlay = "Overlay"
        case sideBySide = "Side by Side"
        case textOnly = "Text Only"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let image = selectedImage {
                    // Image with translations
                    ZStack {
                        switch viewMode {
                        case .overlay:
                            overlayView(image: image)
                        case .sideBySide:
                            sideBySideView(image: image)
                        case .textOnly:
                            textOnlyView()
                        }
                    }
                    
                    // View mode picker
                    Picker("View Mode", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Actions
                    HStack(spacing: 16) {
                        Button {
                            copyAllText()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            shareTranslation()
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            clearImage()
                        } label: {
                            Label("Clear", systemImage: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .padding(.bottom)
                    
                } else {
                    // Empty state / Image picker
                    emptyStateView
                }
            }
            .navigationTitle("Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images
                        ) {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }
                        
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                        
                        Button {
                            pasteFromClipboard()
                        } label: {
                            Label("Paste Image", systemImage: "doc.on.clipboard")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingDebugInfo = true
                    } label: {
                        Image(systemName: "ladybug")
                            .foregroundColor(.orange)
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    await loadImage(from: newItem)
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
            }
            .onChange(of: selectedImage) { _, newImage in
                if newImage != nil {
                    Task {
                        await processImage()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Debug Info", isPresented: $showingDebugInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("""
                📸 Image Translation Status
                
                Blocks found: \(recognizedBlocks.count)
                Blocks translated: \(translatedTexts.count)
                
                Models available: \(MLXModelManager.shared.isGemmaReady ? "Gemma ✅" : "No models")
                OCR ready: ✅
                
                Status: \(processingStatus.isEmpty ? "Ready" : processingStatus)
                """)
            }
        }
        .navigationViewStyle(.stack)  // Fix for iPad navigation issues
    }
    
    // MARK: - View Components
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 70, weight: .light))
                .foregroundColor(.secondary)
            
            Text("Select an Image")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Choose a photo or screenshot to translate the text it contains")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Label("Choose Photo", systemImage: "photo")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.indigo)
                        .cornerRadius(12)
                }
                
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private func overlayView(image: UIImage) -> some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if isProcessing {
                    ProgressView("Processing...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                } else {
                    // Calculate image frame within the container
                    let imageSize = calculateImageSize(image: image, in: geometry.size)
                    let offset = CGPoint(
                        x: (geometry.size.width - imageSize.width) / 2,
                        y: (geometry.size.height - imageSize.height) / 2
                    )
                    
                    ForEach(recognizedBlocks) { block in
                        if let translated = translatedTexts[block.id] {
                            let rect = block.boundingBox(in: imageSize)
                            
                            Text(translated)
                                .font(.system(size: max(rect.height * 0.6, 10)))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.indigo.opacity(0.9))
                                .cornerRadius(4)
                                .position(
                                    x: offset.x + rect.midX,
                                    y: offset.y + rect.minY - 10
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func sideBySideView(image: UIImage) -> some View {
        HStack(spacing: 0) {
            // Original image
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
            
            Divider()
            
            // Translated text
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(recognizedBlocks) { block in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(block.text)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let translated = translatedTexts[block.id] {
                                Text(translated)
                                    .font(.body)
                            } else {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func textOnlyView() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !fullTranslation.isEmpty {
                    Section {
                        Text(fullTranslation)
                            .font(.body)
                            .textSelection(.enabled)
                    } header: {
                        Label("Translation", systemImage: "text.bubble")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !recognizedBlocks.isEmpty {
                    Section {
                        Text(recognizedBlocks.map(\.text).joined(separator: "\n"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    } header: {
                        Label("Original Text", systemImage: "doc.text")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helper Functions
    
    private func calculateImageSize(image: UIImage, in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height
        
        if imageAspect > containerAspect {
            // Image is wider
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // Image is taller
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }
    
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                }
            }
        } catch {
            print("Error loading image: \(error)")
        }
    }
    
    private func processImage() async {
        guard let image = selectedImage else { return }
        
        await MainActor.run {
            isProcessing = true
            processingStatus = "Starting OCR..."
            recognizedBlocks = []
            translatedTexts = [:]
            fullTranslation = ""
        }
        
        do {
            // Run OCR
            await MainActor.run { processingStatus = "Recognizing text..." }
            let result = try await appState.ocrService.recognizeText(from: image)
            
            await MainActor.run {
                recognizedBlocks = result.textBlocks
                processingStatus = "Found \(result.textBlocks.count) text blocks"
            }
            
            if result.textBlocks.isEmpty {
                await MainActor.run {
                    isProcessing = false
                    processingStatus = "No text found in image"
                    errorMessage = "No text was detected in this image. Try with a clearer image or one that contains visible text."
                    showingError = true
                }
                return
            }
            
            // Translate each block
            for (index, block) in result.textBlocks.enumerated() {
                await MainActor.run { 
                    processingStatus = "Translating \(index + 1)/\(result.textBlocks.count)..." 
                }
                
                let translation = try await appState.translationService.translate(
                    text: block.text,
                    from: appState.sourceLanguage,
                    to: appState.targetLanguage
                )
                
                await MainActor.run {
                    translatedTexts[block.id] = translation.translatedText
                }
            }
            
            // Create full translation
            await MainActor.run {
                fullTranslation = recognizedBlocks.compactMap { translatedTexts[$0.id] }.joined(separator: "\n")
                isProcessing = false
                processingStatus = "Done! Translated \(translatedTexts.count) blocks"
            }
            
        } catch {
            DebugLogger.general("Image processing error: \(error.localizedDescription)", level: .error)
            await MainActor.run {
                isProcessing = false
                processingStatus = "Error occurred"
                errorMessage = "Failed to process image: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let image = UIPasteboard.general.image {
            selectedImage = image
        }
    }
    
    private func copyAllText() {
        UIPasteboard.general.string = fullTranslation
    }
    
    private func shareTranslation() {
        // Would present share sheet
    }
    
    private func clearImage() {
        selectedImage = nil
        selectedItem = nil
        recognizedBlocks = []
        translatedTexts = [:]
        fullTranslation = ""
    }
}

// MARK: - Image Picker (Camera)

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    ImageTranslateView()
        .environment(AppState())
}
