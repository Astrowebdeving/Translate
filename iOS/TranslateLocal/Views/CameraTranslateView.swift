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
    @Environment(AppState.self) var appState
    
    @State private var cameraManager = CameraManager()
    @State private var recognizedBlocks: [RecognizedTextBlock] = []
    @State private var translatedTexts: [UUID: String] = [:]
    @State private var isTranslating = false
    @State private var showLanguagePicker = false
    @State private var flashEnabled = false
    @State private var isPaused = false
    @State private var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    @State private var lastProcessTime: Date = .distantPast
    
    private let processingInterval: TimeInterval = 1.0 // Process every 1 second for better performance
    
    var body: some View {
        ZStack {
            // Check if running on simulator first
            if CameraManager.isSimulator {
                simulatorPlaceholderView
            } else {
                switch cameraPermissionStatus {
                case .authorized:
                    cameraView
                case .notDetermined:
                    permissionRequestView
                case .denied, .restricted:
                    permissionDeniedView
                @unknown default:
                    permissionRequestView
                }
            }
        }
        .onAppear {
            if !CameraManager.isSimulator {
                checkCameraPermission()
            }
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    // MARK: - Simulator Placeholder
    
    private var simulatorPlaceholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 70))
                .foregroundColor(.orange)
            
            Text("Camera Not Available")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Camera features are not available in the iOS Simulator. Please run on a physical device to test camera translation.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Show a demo mode hint
            VStack(spacing: 12) {
                Text("💡 Tip")
                    .font(.headline)
                    .foregroundColor(.indigo)
                
                Text("Use the \"Image\" tab to test translation with photos from your library.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.indigo.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Camera View
    
    private var cameraView: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(session: cameraManager.captureSession)
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
                topControlsBar
                
                Spacer()
                
                // Bottom Status
                if isTranslating {
                    statusIndicator
                }
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet()
        }
        .onChange(of: cameraManager.frameCount) { _, _ in
            if let frame = cameraManager.currentFrame {
                handleFrame(frame)
            }
        }
    }
    
    private var topControlsBar: some View {
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
                if isPaused {
                    recognizedBlocks = []
                    translatedTexts = [:]
                }
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
    }
    
    private var statusIndicator: some View {
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
    
    // MARK: - Permission Views
    
    private var permissionRequestView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.indigo)
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("TranslateLocal needs camera access to recognize and translate text in real-time.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                requestCameraPermission()
            } label: {
                Text("Allow Camera Access")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Camera Access Denied")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Please enable camera access in Settings to use real-time translation.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Permission Handling
    
    private func checkCameraPermission() {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                cameraPermissionStatus = granted ? .authorized : .denied
            }
        }
    }
    
    // MARK: - Frame Processing
    
    private func handleFrame(_ pixelBuffer: CVPixelBuffer) {
        // Throttle processing
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= processingInterval else { return }
        guard !isPaused, !appState.ocrService.isProcessing else { return }
        
        lastProcessTime = now
        
        Task {
            do {
                let result = try await appState.ocrService.recognizeText(from: pixelBuffer)
                
                await MainActor.run {
                    recognizedBlocks = result.textBlocks
                }
                
                // Translate new blocks (limit to first 3)
                for block in result.textBlocks.prefix(3) {
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
        
        await MainActor.run {
            isTranslating = true
        }
        
        do {
            let result = try await appState.translationService.translate(
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
            await MainActor.run {
                isTranslating = false
            }
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
            y: max(rect.minY - 15, 20)
        )
    }
    
    private var dynamicFontSize: CGFloat {
        let height = block.boundingBox.height * containerSize.height
        return max(min(height * 0.8, 24), 12)
    }
}

// MARK: - Camera Manager

@MainActor @Observable
class CameraManager: NSObject {
    var currentFrame: CVPixelBuffer?
    var frameCount: Int = 0  // Used to trigger onChange in SwiftUI
    var isRunning = false
    var error: String?
    
    let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.translatelocal.camera", qos: .userInteractive)
    private var isConfigured = false
    
    /// Check if we're running on a simulator (no camera available)
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    /// Check if camera is available on this device
    static var isCameraAvailable: Bool {
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }
    
    override init() {
        super.init()
        // Don't setup on simulator - it will crash
        if !CameraManager.isSimulator && CameraManager.isCameraAvailable {
            setupSession()
        }
    }
    
    private func setupSession() {
        guard !isConfigured else { return }
        guard !CameraManager.isSimulator else {
            error = "Camera not available on Simulator"
            return
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720
        
        // Add video input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            error = "No camera device found"
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                error = "Cannot add camera input"
                captureSession.commitConfiguration()
                return
            }
        } catch {
            self.error = "Camera input error: \(error.localizedDescription)"
            captureSession.commitConfiguration()
            return
        }
        
        // Configure video output
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            error = "Cannot add video output"
            captureSession.commitConfiguration()
            return
        }
        
        // Set orientation
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
        
        captureSession.commitConfiguration()
        isConfigured = true
    }
    
    func startSession() {
        // Don't try to start on simulator
        guard !CameraManager.isSimulator else {
            error = "Camera not available on Simulator"
            return
        }
        
        guard isConfigured else {
            error = "Camera not configured"
            return
        }
        
        guard !captureSession.isRunning else { return }
        
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Wrap in do-catch to prevent crashes
            do {
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.isRunning = true
                    self.error = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = "Failed to start camera: \(error.localizedDescription)"
                    self.isRunning = false
                }
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
        guard !CameraManager.isSimulator,
              let device = AVCaptureDevice.default(for: .video),
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
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        Task { @MainActor [weak self] in
            self?.currentFrame = pixelBuffer
            self?.frameCount += 1  // Trigger SwiftUI onChange
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
    
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
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        @Bindable var state = appState
        
        NavigationView {
            List {
                Section("Source Language") {
                    ForEach(Language.allLanguages) { language in
                        Button {
                            state.sourceLanguage = language
                            state.saveSettings()
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
                            state.targetLanguage = language
                            state.saveSettings()
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
        .environment(AppState())
}
