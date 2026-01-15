//
//  PiPService.swift
//  TranslateLocal
//
//  Picture-in-Picture service for displaying translations in a floating window
//  Uses AVSampleBufferDisplayLayer to render dynamic translation content
//

import Foundation
import AVKit
import UIKit
import SwiftUI
import Combine

/// Service for managing Picture-in-Picture translation display
@MainActor @Observable
class PiPService: NSObject {
    
    // MARK: - Observable Properties
    
    private(set) var isPiPActive = false
    private(set) var isPiPSupported = false
    private(set) var currentTranslation: String = ""
    private(set) var error: PiPError?
    private(set) var frameCount: Int = 0
    private(set) var statusMessage: String = "Not started"
    
    /// Current overlay mode (toggle button vs full overlay)
    private(set) var overlayMode: OverlayMode = .toggle
    
    /// Whether translation overlay is enabled (controlled by toggle)
    private(set) var isTranslationEnabled = false
    
    /// Current positioned translations for overlay display
    private(set) var positionedTranslations: [PositionedTranslation] = []
    
    /// Overlay opacity (0-1)
    var overlayOpacity: Double = 0.3
    
    // MARK: - Device Capability
    
    /// Check if the full overlay feature is available (real device only)
    var isOverlayFeatureAvailable: Bool {
        #if targetEnvironment(simulator)
        // Screen recording doesn't work on simulator, so overlay feature is not useful
        return false
        #else
        return isPiPSupported && UIDevice.current.userInterfaceIdiom == .pad
        #endif
    }
    
    // MARK: - Private Properties
    
    private var pipController: AVPictureInPictureController?
    private var pipContentViewController: PiPContentViewController?
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    
    /// Source view that hosts the display layer (must be in view hierarchy for PiP to work)
    private var sourceView: UIView?
    
    /// Audio session for keeping app alive in background
    private let audioSession = AVAudioSession.sharedInstance()
    
    /// Timer for updating PiP content
    private var updateTimer: Timer?
    
    /// Refresh rate for PiP content (frames per second)
    private var refreshRate: TimeInterval = 1.0 / 5.0  // 5 FPS default
    
    /// Content renderer
    private var contentRenderer: PiPContentRenderer?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        DebugLogger.pip("PiPService initialized", level: .info)
        checkPiPSupport()
    }
    
    // MARK: - Public Methods
    
    /// Check if PiP is supported on this device
    func checkPiPSupport() {
        let systemSupported = AVPictureInPictureController.isPictureInPictureSupported()
        
        #if targetEnvironment(simulator)
        // On iPad Simulator, PiP is supported even though isPictureInPictureSupported() may return false
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        if isIPad {
            isPiPSupported = true
            DebugLogger.pip("iPad Simulator detected - PiP should work (system reports: \(systemSupported))", level: .info)
        } else {
            isPiPSupported = false
            DebugLogger.pip("iPhone Simulator - PiP is not supported", level: .warning)
        }
        DebugLogger.pip("Running on Simulator - Screen recording will not work, but PiP window will display", level: .warning)
        #else
        isPiPSupported = systemSupported
        DebugLogger.pip("PiP supported: \(isPiPSupported)", level: isPiPSupported ? .success : .warning)
        #endif
    }
    
    /// Start PiP mode
    func startPiP() async throws {
        DebugLogger.pip("Starting PiP...", level: .info)
        statusMessage = "Starting..."
        
        guard isPiPSupported else {
            DebugLogger.pip("PiP not supported on this device", level: .error)
            throw PiPError.notSupported
        }
        
        // Configure audio session for background mode
        do {
            try configureAudioSession()
            DebugLogger.pip("Audio session configured", level: .success)
        } catch {
            DebugLogger.pip("Audio session failed: \(error)", level: .error)
            throw error
        }
        
        // Create PiP content view controller
        setupPiPController()
        
        // Start the update timer
        startUpdateTimer()
        
        isPiPActive = true
        statusMessage = "PiP Active"
        DebugLogger.pip("PiP started successfully", level: .success)
    }
    
    /// Stop PiP mode
    func stopPiP() {
        DebugLogger.pip("Stopping PiP...", level: .info)
        
        stopUpdateTimer()
        
        #if targetEnvironment(simulator)
        stopDemoMode()
        #endif
        
        pipController?.stopPictureInPicture()
        pipController = nil
        pipContentViewController = nil
        sampleBufferDisplayLayer = nil
        
        // Clean up source view
        sourceView?.removeFromSuperview()
        sourceView = nil
        
        isPiPActive = false
        statusMessage = "Stopped"
        frameCount = 0
        DebugLogger.pip("PiP stopped", level: .info)
    }
    
    /// Update the translation content displayed in PiP
    func updateContent(_ translation: String, originalText: String? = nil) {
        currentTranslation = translation
        contentRenderer?.update(translation: translation, originalText: originalText)
        DebugLogger.pip("Content updated: \(translation.prefix(50))...", level: .debug)
    }
    
    /// Show waiting state
    func showWaiting() {
        contentRenderer?.showWaiting()
        currentTranslation = "Waiting for broadcast..."
        statusMessage = "Waiting for broadcast"
        DebugLogger.pip("Showing waiting state", level: .info)
    }
    
    /// Show error state
    func showError(_ message: String) {
        contentRenderer?.showError(message)
        error = PiPError.displayError(message)
        statusMessage = "Error: \(message)"
        DebugLogger.pip("Error state: \(message)", level: .error)
    }
    
    // MARK: - Overlay Mode Control
    
    /// Toggle translation overlay on/off
    func toggleOverlay() {
        isTranslationEnabled.toggle()
        
        if isTranslationEnabled {
            overlayMode = .fullOverlay
            refreshRate = 1.0 / 2.0  // 2 FPS for full overlay (battery saving)
            statusMessage = "Overlay Active"
            DebugLogger.pip("Overlay enabled - switching to full overlay mode", level: .info)
        } else {
            overlayMode = .toggle
            refreshRate = 1.0 / 5.0  // 5 FPS for toggle button
            statusMessage = "Overlay Disabled"
            DebugLogger.pip("Overlay disabled - switching to toggle mode", level: .info)
        }
        
        // Update renderer with new mode
        contentRenderer?.setMode(overlayMode, isEnabled: isTranslationEnabled)
        
        // Restart update timer with new refresh rate
        if isPiPActive {
            startUpdateTimer()
        }
    }
    
    /// Set overlay mode directly
    func setOverlayMode(_ mode: OverlayMode) {
        overlayMode = mode
        isTranslationEnabled = (mode == .fullOverlay)
        contentRenderer?.setMode(mode, isEnabled: isTranslationEnabled)
        DebugLogger.pip("Overlay mode set to: \(mode)", level: .debug)
    }
    
    /// Update positioned translations for overlay display
    func updatePositionedTranslations(_ translations: [PositionedTranslation]) {
        positionedTranslations = translations
        contentRenderer?.updatePositionedTranslations(translations)
        
        if !translations.isEmpty {
            statusMessage = "Translating \(translations.count) blocks"
        }
        
        DebugLogger.pip("Updated \(translations.count) positioned translations", level: .debug)
    }
    
    /// Set overlay opacity
    func setOverlayOpacity(_ opacity: Double) {
        overlayOpacity = min(max(opacity, 0), 1)
        contentRenderer?.setOverlayOpacity(overlayOpacity)
    }
    
    // MARK: - Gemma Smart Features
    
    /// Whether Gemma is available for smart features
    var isGemmaAvailable: Bool {
        GemmaService.shared.isLoaded || MLXModelManager.shared.isGemmaReady
    }
    
    /// Smart overlay mode enabled (uses Gemma for analysis)
    private(set) var smartOverlayEnabled = false
    
    /// Last analysis result from Gemma
    private(set) var lastAnalysis: PiPAnalysis?
    
    /// Enable smart overlay mode using Gemma
    func enableSmartOverlay() async {
        guard isGemmaAvailable else {
            DebugLogger.pip("Gemma not available, cannot enable smart overlay", level: .warning)
            return
        }
        
        // Check for sufficient RAM (8GB+ required for stable background inference)
        guard MLXModelManager.shared.hasSufficientMemoryForPiP() else {
            DebugLogger.pip("Smart overlay disabled: Device has insufficient RAM (< 8GB)", level: .error)
            statusMessage = "Smart features require 8GB+ RAM"
            return
        }
        
        // Load Gemma if not already loaded
        if !GemmaService.shared.isLoaded && MLXModelManager.shared.isGemmaReady {
            do {
                try await GemmaService.shared.loadModel()
                DebugLogger.pip("Loaded GemmaService for smart overlay", level: .success)
            } catch {
                DebugLogger.pip("Failed to load Gemma: \(error.localizedDescription)", level: .error)
                return
            }
        }
        
        smartOverlayEnabled = true
        statusMessage = "Smart Overlay Active"
        DebugLogger.pip("Smart overlay enabled with Gemma", level: .success)
    }
    
    /// Disable smart overlay mode
    func disableSmartOverlay() {
        smartOverlayEnabled = false
        lastAnalysis = nil
        statusMessage = "Smart Overlay Disabled"
        DebugLogger.pip("Smart overlay disabled", level: .info)
    }
    
    /// Analyze current screen content using Gemma
    /// Returns analysis of content type, summary, and suggested actions
    func analyzeScreenWithGemma() async throws -> PiPAnalysis? {
        guard GemmaService.shared.isLoaded else {
            DebugLogger.pip("Gemma not loaded, cannot analyze", level: .warning)
            return nil
        }
        
        guard !positionedTranslations.isEmpty else {
            DebugLogger.pip("No content to analyze", level: .debug)
            return nil
        }
        
        let texts = positionedTranslations.map { $0.originalText }
        
        do {
            let analysis = try await GemmaService.shared.analyzeForPiP(textBlocks: texts)
            lastAnalysis = analysis
            
            DebugLogger.pip("Gemma analysis: type=\(analysis.contentType), summary=\(analysis.summary.prefix(50))...", level: .info)
            
            return analysis
        } catch {
            DebugLogger.pip("Gemma analysis failed: \(error.localizedDescription)", level: .error)
            throw error
        }
    }
    
    /// Get smart suggestions based on Gemma analysis
    func getSmartSuggestions() -> [String] {
        return lastAnalysis?.suggestedActions ?? []
    }
    
    /// Demo mode for testing PiP on simulator
    /// This cycles through sample translations to verify PiP is working
    #if targetEnvironment(simulator)
    private var demoTimer: Timer?
    private var demoIndex = 0
    private let demoTranslations = [
        ("Hello, World!", "こんにちは、世界！"),
        ("Welcome to TranslateLocal", "TranslateLocalへようこそ"),
        ("Screen translation is amazing", "画面翻訳は素晴らしいです"),
        ("This is running in PiP mode", "これはPiPモードで動作しています"),
        ("No network required!", "ネットワーク不要！")
    ]
    
    /// Start demo mode with sample translations (simulator only)
    func startDemoMode() {
        DebugLogger.pip("Starting demo mode for simulator testing", level: .info)
        statusMessage = "Demo Mode Active"
        
        // Show first translation immediately
        showDemoTranslation()
        
        // Cycle through translations every 3 seconds
        demoTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showDemoTranslation()
            }
        }
    }
    
    /// Stop demo mode
    func stopDemoMode() {
        demoTimer?.invalidate()
        demoTimer = nil
        demoIndex = 0
        DebugLogger.pip("Demo mode stopped", level: .info)
    }
    
    private func showDemoTranslation() {
        let (original, translated) = demoTranslations[demoIndex]
        updateContent(translated, originalText: original)
        demoIndex = (demoIndex + 1) % demoTranslations.count
    }
    #endif
    
    // MARK: - Private Methods
    
    private func configureAudioSession() throws {
        DebugLogger.pip("Configuring audio session...", level: .debug)
        do {
            // Configure for background playback
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try audioSession.setActive(true)
            DebugLogger.pip("Audio session active", level: .success)
        } catch {
            #if targetEnvironment(simulator)
            // Audio session may fail on simulator but PiP can still work
            DebugLogger.pip("Audio session error (expected on simulator): \(error)", level: .warning)
            // Don't throw on simulator - continue anyway
            #else
            DebugLogger.pip("Audio session error: \(error)", level: .error)
            throw PiPError.audioSessionFailed(error.localizedDescription)
            #endif
        }
    }
    
    private func setupPiPController() {
        DebugLogger.pip("Setting up PiP controller...", level: .debug)
        
        // Create the sample buffer display layer
        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.black.cgColor
        displayLayer.frame = CGRect(x: 0, y: 0, width: 480, height: 270)
        self.sampleBufferDisplayLayer = displayLayer
        DebugLogger.pip("Display layer created", level: .debug)
        
        // CRITICAL: The display layer MUST be added to a visible view hierarchy for PiP to work
        // Create a source view and add it to the key window
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            DebugLogger.pip("Could not find key window!", level: .error)
            return
        }
        
        // Create a small source view (it will be hidden but must be in hierarchy)
        let source = UIView(frame: CGRect(x: 0, y: 0, width: 480, height: 270))
        source.backgroundColor = .clear
        source.layer.addSublayer(displayLayer)
        displayLayer.frame = source.bounds
        
        // Add to window at a position that won't interfere with UI
        // The view needs to be "visible" (not hidden, alpha > 0) but can be off-screen or tiny
        source.frame = CGRect(x: -1, y: -1, width: 1, height: 1)  // 1x1 pixel off-screen
        source.clipsToBounds = true
        keyWindow.addSubview(source)
        self.sourceView = source
        DebugLogger.pip("Source view added to window hierarchy", level: .success)
        
        // Create content renderer
        contentRenderer = PiPContentRenderer(displayLayer: displayLayer)
        DebugLogger.pip("Content renderer created", level: .debug)
        
        // Render an initial frame BEFORE creating the controller
        contentRenderer?.showWaiting()
        contentRenderer?.renderFrame()
        DebugLogger.pip("Initial frame rendered", level: .debug)
        
        // Create the content source
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        DebugLogger.pip("Content source created", level: .debug)
        
        // Create PiP controller
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        
        // Disable automatic PiP to have full control
        if #available(iOS 14.2, *) {
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        }
        
        if pipController == nil {
            DebugLogger.pip("Failed to create PiP controller!", level: .error)
            statusMessage = "Failed to create PiP controller"
        } else {
            DebugLogger.pip("PiP controller created successfully", level: .success)
        }
        
        // Attempt to start PiP after a delay to allow setup to complete
        #if targetEnvironment(simulator)
        let startDelay: TimeInterval = 2.0  // Longer delay for simulator
        #else
        let startDelay: TimeInterval = 1.0
        #endif
        
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) { [weak self] in
            self?.attemptToStartPiP()
        }
    }
    
    private func attemptToStartPiP() {
        guard let controller = self.pipController else {
            DebugLogger.pip("PiP controller nil when trying to start", level: .error)
            statusMessage = "PiP controller not available"
            return
        }
        
        DebugLogger.pip("Attempting to start PiP window...", level: .info)
        DebugLogger.pip("isPictureInPicturePossible: \(controller.isPictureInPicturePossible)", level: .debug)
        DebugLogger.pip("isPictureInPictureActive: \(controller.isPictureInPictureActive)", level: .debug)
        
        if controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
            DebugLogger.pip("startPictureInPicture() called", level: .info)
        } else {
            DebugLogger.pip("PiP not possible yet, will retry...", level: .warning)
            statusMessage = "PiP initializing..."
            
            // Retry after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, let controller = self.pipController else { return }
                
                DebugLogger.pip("Retry: isPictureInPicturePossible: \(controller.isPictureInPicturePossible)", level: .debug)
                
                if controller.isPictureInPicturePossible {
                    controller.startPictureInPicture()
                    DebugLogger.pip("startPictureInPicture() called on retry", level: .info)
                } else {
                    #if targetEnvironment(simulator)
                    // On simulator, force try anyway
                    controller.startPictureInPicture()
                    DebugLogger.pip("Force starting PiP on simulator", level: .warning)
                    #else
                    DebugLogger.pip("PiP still not possible after retry", level: .error)
                    self.statusMessage = "PiP not available"
                    #endif
                }
            }
        }
    }
    
    private func startUpdateTimer() {
        stopUpdateTimer()
        
        DebugLogger.pip("Starting update timer at \(1.0/refreshRate) FPS", level: .debug)
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: refreshRate, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.contentRenderer?.renderFrame()
                self?.frameCount += 1
            }
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension PiPService: AVPictureInPictureControllerDelegate {
    nonisolated func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DebugLogger.pip("PiP will start", level: .info)
        Task { @MainActor [weak self] in
            self?.isPiPActive = true
            self?.statusMessage = "PiP starting..."
        }
    }
    
    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DebugLogger.pip("PiP did start successfully!", level: .success)
        Task { @MainActor [weak self] in
            self?.statusMessage = "PiP running"
        }
    }
    
    nonisolated func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DebugLogger.pip("PiP will stop", level: .info)
    }
    
    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DebugLogger.pip("PiP did stop", level: .info)
        Task { @MainActor [weak self] in
            self?.isPiPActive = false
            self?.statusMessage = "PiP stopped"
        }
    }
    
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        DebugLogger.pip("PiP failed to start: \(error.localizedDescription)", level: .error)
        Task { @MainActor [weak self] in
            self?.error = PiPError.startFailed(error.localizedDescription)
            self?.isPiPActive = false
            self?.statusMessage = "Failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate

extension PiPService: AVPictureInPictureSampleBufferPlaybackDelegate {
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        // Handle play/pause if needed
    }
    
    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        // Return infinite time range for live content
        return CMTimeRange(start: .zero, duration: .positiveInfinity)
    }
    
    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return false
    }
    
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        // Handle size change if needed
    }
    
    nonisolated func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}

// MARK: - PiP Content Renderer

/// Renders translation content to CMSampleBuffers for PiP display
/// Supports both toggle mode (small button) and full overlay mode
class PiPContentRenderer {
    
    private let displayLayer: AVSampleBufferDisplayLayer
    private var currentView: PiPOverlayView
    private var hostingController: UIHostingController<PiPOverlayView>?
    
    /// Current overlay mode
    private var overlayMode: OverlayMode = .toggle
    
    /// Whether translation is enabled
    private var isTranslationEnabled = false
    
    /// Current positioned translations
    private var positionedTranslations: [PositionedTranslation] = []
    
    /// Overlay opacity
    private var overlayOpacity: Double = 0.3
    
    /// Current display status
    private var status: PiPDisplayStatus = .waiting
    
    /// Size of the rendered content (changes based on mode)
    private var renderSize: CGSize {
        overlayMode.size
    }
    
    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        self.currentView = PiPOverlayView(mode: .toggle, status: .inactive)
    }
    
    /// Set the overlay mode
    func setMode(_ mode: OverlayMode, isEnabled: Bool) {
        overlayMode = mode
        isTranslationEnabled = isEnabled
        status = isEnabled ? .translating : .inactive
        
        // Recreate hosting controller with new size
        hostingController = nil
        updateCurrentView()
    }
    
    /// Update positioned translations
    func updatePositionedTranslations(_ translations: [PositionedTranslation]) {
        positionedTranslations = translations
        status = translations.isEmpty ? .waiting : .translating
        updateCurrentView()
    }
    
    /// Set overlay opacity
    func setOverlayOpacity(_ opacity: Double) {
        overlayOpacity = opacity
        updateCurrentView()
    }
    
    /// Update the translation content (legacy simple mode)
    func update(translation: String, originalText: String? = nil) {
        status = .translating
        currentView = PiPOverlayView(
            mode: overlayMode,
            status: status,
            isTranslationEnabled: isTranslationEnabled,
            positionedTranslations: positionedTranslations,
            overlayOpacity: overlayOpacity,
            translatedText: translation,
            originalText: originalText
        )
    }
    
    /// Show waiting state
    func showWaiting() {
        status = .waiting
        updateCurrentView()
    }
    
    /// Show error state
    func showError(_ message: String) {
        status = .error
        currentView = PiPOverlayView(
            mode: overlayMode,
            status: .error,
            isTranslationEnabled: isTranslationEnabled,
            positionedTranslations: [],
            overlayOpacity: overlayOpacity,
            translatedText: message
        )
    }
    
    /// Update the current view based on state
    private func updateCurrentView() {
        currentView = PiPOverlayView(
            mode: overlayMode,
            status: status,
            isTranslationEnabled: isTranslationEnabled,
            positionedTranslations: positionedTranslations,
            overlayOpacity: overlayOpacity
        )
    }
    
    /// Render a new frame to the display layer
    func renderFrame() {
        guard let sampleBuffer = createSampleBuffer() else { return }
        
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        
        displayLayer.enqueue(sampleBuffer)
    }
    
    /// Create a CMSampleBuffer from the current view
    private func createSampleBuffer() -> CMSampleBuffer? {
        let size = renderSize
        
        // Create or update hosting controller
        if hostingController == nil {
            hostingController = UIHostingController(rootView: currentView)
            hostingController?.view.frame = CGRect(origin: .zero, size: size)
            hostingController?.view.backgroundColor = .clear
        }
        
        // Update the view
        hostingController?.rootView = currentView
        hostingController?.view.frame = CGRect(origin: .zero, size: size)
        hostingController?.view.layoutIfNeeded()
        
        // Render to image
        guard let image = renderViewToImage(size: size) else { return nil }
        guard let pixelBuffer = createPixelBuffer(from: image) else { return nil }
        
        // Create sample buffer from pixel buffer
        return createSampleBuffer(from: pixelBuffer)
    }
    
    /// Render the SwiftUI view to a UIImage
    private func renderViewToImage(size: CGSize) -> UIImage? {
        guard let view = hostingController?.view else { return nil }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }
    
    /// Create a CVPixelBuffer from a UIImage
    private func createPixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
                kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!
            ] as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
    
    /// Create a CMSampleBuffer from a CVPixelBuffer
    private func createSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var formatDescription: CMVideoFormatDescription?
        
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard let format = formatDescription else { return nil }
        
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 10),
            presentationTimeStamp: CMTime(value: CMTimeValue(CACurrentMediaTime() * 1000), timescale: 1000),
            decodeTimeStamp: .invalid
        )
        
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: format,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        return sampleBuffer
    }
}

// MARK: - PiP Content View Controller

class PiPContentViewController: UIViewController {
    
    private let displayLayer: AVSampleBufferDisplayLayer
    
    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.addSublayer(displayLayer)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        displayLayer.frame = view.bounds
    }
}

// MARK: - PiP Errors

enum PiPError: LocalizedError {
    case notSupported
    case startFailed(String)
    case audioSessionFailed(String)
    case displayError(String)
    
    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Picture-in-Picture is not supported on this device"
        case .startFailed(let reason):
            return "Failed to start PiP: \(reason)"
        case .audioSessionFailed(let reason):
            return "Audio session error: \(reason)"
        case .displayError(let reason):
            return "Display error: \(reason)"
        }
    }
}
