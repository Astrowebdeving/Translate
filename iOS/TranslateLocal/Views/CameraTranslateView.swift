//
//  CameraTranslateView.swift
//  TranslateLocal
//
//  Real-time camera-based text translation
//

import SwiftUI
import AVFoundation
import Vision

struct CameraTranslateView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var ocrService: OCRService
    @EnvironmentObject var translationService: TranslationService
    
    @StateObject private var cameraManager = CameraManager()
    
    @State private var recognizedBlocks: [RecognizedTextBlock] = []
    @State private var translatedTexts: [UUID: String] = [:]
    @State private var isTranslating = false
    @State private var showLanguagePicker = false
    @State private var flashEnabled = false
    @State private var isPaused = false
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Text Overlay
            GeometryReader { geometry in
                ForEach(recognizedBlocks) { block in
                    TextBlockOverlay(
                        block: block,
                        translatedText: translatedTexts[block.id],
                        containerSize: geometry.size
                    )
                }
            }
            
            // Controls Overlay
            VStack {
                // Top Bar
                HStack {
                    Button {
                        flashEnabled.toggle()
                        cameraManager.toggleFlash(flashEnabled)
                    } label: {
                        Image(systemName: flashEnabled ? "bolt.fill" : "bolt.slash")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Language Display
                    Button {
                        showLanguagePicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Text(appState.sourceLanguage.id.uppercased())
                                .font(.caption.bold())
                            
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                            
                            Text(appState.targetLanguage.id.uppercased())
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    Button {
                        isPaused.toggle()
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
                
                // Bottom Status
                if isTranslating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Translating...")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .padding(.bottom, 100)
                }
            }
        }
        .onAppear {
            cameraManager.startSession()
            startProcessing()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet()
        }
        .onChange(of: cameraManager.currentFrame) { _, frame in
            if !isPaused, let frame = frame {
                processFrame(frame)
            }
        }
    }
    
    private func startProcessing() {
        // Start the camera frame processing loop
    }
    
    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard !isPaused, !ocrService.isProcessing else { return }
        
        Task {
            do {
                let result = try await ocrService.recognizeText(from: pixelBuffer)
                
                await MainActor.run {
                    recognizedBlocks = result.textBlocks
                }
                
                // Translate new blocks
                for block in result.textBlocks {
                    if translatedTexts[block.id] == nil {
                        await translateBlock(block)
                    }
                }
            } catch {
                print("OCR Error: \(error)")
            }
        }
    }
    
    private func translateBlock(_ block: RecognizedTextBlock) async {
        guard !block.text.isEmpty else { return }
        
        isTranslating = true
        
        do {
            let result = try await translationService.translate(
                text: block.text,
                from: appState.sourceLanguage,
                to: appState.targetLanguage
            )
            
            await MainActor.run {
                translatedTexts[block.id] = result.translatedText
                isTranslating = false
            }
        } catch {
            print("Translation Error: \(error)")
            isTranslating = false
        }
    }
}

// MARK: - Text Block Overlay

struct TextBlockOverlay: View {
    let block: RecognizedTextBlock
    let translatedText: String?
    let containerSize: CGSize
    
    var body: some View {
        let rect = block.boundingBox(in: containerSize)
        
        VStack(alignment: .leading, spacing: 2) {
            if let translated = translatedText {
                Text(translated)
                    .font(.system(size: dynamicFontSize))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.85))
                    .cornerRadius(4)
            }
        }
        .position(
            x: rect.midX,
            y: rect.midY - rect.height / 2 - 20
        )
    }
    
    private var dynamicFontSize: CGFloat {
        // Scale font size based on bounding box
        let height = block.boundingBox.height * containerSize.height
        return max(min(height * 0.8, 24), 10)
    }
}

// MARK: - Camera Manager

class CameraManager: NSObject, ObservableObject {
    @Published var currentFrame: CVPixelBuffer?
    @Published var isRunning = false
    
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.translatelocal.camera", qos: .userInteractive)
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720
        
        // Add video input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        // Configure video output
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Set orientation
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
        
        captureSession.commitConfiguration()
    }
    
    func startSession() {
        guard !captureSession.isRunning else { return }
        
        processingQueue.async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
            }
        }
    }
    
    func stopSession() {
        guard captureSession.isRunning else { return }
        
        processingQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
    }
    
    func toggleFlash(_ enabled: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = enabled ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Flash error: \(error)")
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        DispatchQueue.main.async {
            self.currentFrame = pixelBuffer
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let cameraManager: CameraManager
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = cameraManager.captureSession
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {}
    
    class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Language Picker Sheet

struct LanguagePickerSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Source Language") {
                    ForEach(Language.allLanguages) { language in
                        Button {
                            appState.sourceLanguage = language
                            appState.saveSettings()
                        } label: {
                            HStack {
                                Text(language.name)
                                Spacer()
                                Text(language.nativeName)
                                    .foregroundColor(.secondary)
                                if appState.sourceLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.indigo)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section("Target Language") {
                    ForEach(Language.allLanguages) { language in
                        Button {
                            appState.targetLanguage = language
                            appState.saveSettings()
                        } label: {
                            HStack {
                                Text(language.name)
                                Spacer()
                                Text(language.nativeName)
                                    .foregroundColor(.secondary)
                                if appState.targetLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.indigo)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        appState.swapLanguages()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CameraTranslateView()
        .environmentObject(AppState())
        .environmentObject(OCRService())
        .environmentObject(TranslationService())
}
