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
    
    // MARK: - Private Properties
    
    private var pipController: AVPictureInPictureController?
    private var pipContentViewController: PiPContentViewController?
    private var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer?
    
    /// Audio session for keeping app alive in background
    private let audioSession = AVAudioSession.sharedInstance()
    
    /// Timer for updating PiP content
    private var updateTimer: Timer?
    
    /// Refresh rate for PiP content (frames per second)
    private let refreshRate: TimeInterval = 1.0 / 5.0  // 5 FPS (reduced for stability)
    
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
        isPiPSupported = AVPictureInPictureController.isPictureInPictureSupported()
        DebugLogger.pip("PiP supported: \(isPiPSupported)", level: isPiPSupported ? .success : .warning)
        
        #if targetEnvironment(simulator)
        DebugLogger.pip("Running on Simulator - PiP may have limited functionality", level: .warning)
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
        
        pipController?.stopPictureInPicture()
        pipController = nil
        pipContentViewController = nil
        sampleBufferDisplayLayer = nil
        
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
            DebugLogger.pip("Audio session error: \(error)", level: .error)
            throw PiPError.audioSessionFailed(error.localizedDescription)
        }
    }
    
    private func setupPiPController() {
        DebugLogger.pip("Setting up PiP controller...", level: .debug)
        
        // Create the sample buffer display layer
        let displayLayer = AVSampleBufferDisplayLayer()
        displayLayer.videoGravity = .resizeAspect
        displayLayer.backgroundColor = UIColor.black.cgColor
        self.sampleBufferDisplayLayer = displayLayer
        DebugLogger.pip("Display layer created", level: .debug)
        
        // Create content renderer
        contentRenderer = PiPContentRenderer(displayLayer: displayLayer)
        DebugLogger.pip("Content renderer created", level: .debug)
        
        // Render an initial frame
        contentRenderer?.showWaiting()
        contentRenderer?.renderFrame()
        
        // Create the content source
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: displayLayer,
            playbackDelegate: self
        )
        DebugLogger.pip("Content source created", level: .debug)
        
        // Create PiP controller
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        
        if pipController == nil {
            DebugLogger.pip("Failed to create PiP controller!", level: .error)
        } else {
            DebugLogger.pip("PiP controller created", level: .success)
        }
        
        // Attempt to start PiP after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, let controller = self.pipController else {
                DebugLogger.pip("PiP controller nil when trying to start", level: .error)
                return
            }
            
            DebugLogger.pip("Attempting to start PiP window...", level: .info)
            
            if controller.isPictureInPicturePossible {
                controller.startPictureInPicture()
                DebugLogger.pip("startPictureInPicture() called", level: .info)
            } else {
                DebugLogger.pip("PiP not possible at this time", level: .warning)
                self.statusMessage = "PiP not possible - try again"
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
class PiPContentRenderer {
    
    private let displayLayer: AVSampleBufferDisplayLayer
    private var currentView: PiPOverlayView
    private var hostingController: UIHostingController<PiPOverlayView>?
    
    /// Size of the rendered content
    private let renderSize = CGSize(width: 480, height: 270)  // 16:9 aspect ratio
    
    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        self.currentView = PiPOverlayView()
    }
    
    /// Update the translation content
    func update(translation: String, originalText: String? = nil) {
        currentView = PiPOverlayView(
            translatedText: translation,
            originalText: originalText,
            status: .translating
        )
    }
    
    /// Show waiting state
    func showWaiting() {
        currentView = PiPOverlayView(
            translatedText: "",
            originalText: nil,
            status: .waiting
        )
    }
    
    /// Show error state
    func showError(_ message: String) {
        currentView = PiPOverlayView(
            translatedText: message,
            originalText: nil,
            status: .error
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
        // Create hosting controller if needed
        if hostingController == nil {
            hostingController = UIHostingController(rootView: currentView)
            hostingController?.view.frame = CGRect(origin: .zero, size: renderSize)
        }
        
        // Update the view
        hostingController?.rootView = currentView
        hostingController?.view.layoutIfNeeded()
        
        // Render to image
        guard let image = renderViewToImage() else { return nil }
        guard let pixelBuffer = createPixelBuffer(from: image) else { return nil }
        
        // Create sample buffer from pixel buffer
        return createSampleBuffer(from: pixelBuffer)
    }
    
    /// Render the SwiftUI view to a UIImage
    private func renderViewToImage() -> UIImage? {
        guard let view = hostingController?.view else { return nil }
        
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { context in
            view.drawHierarchy(in: CGRect(origin: .zero, size: renderSize), afterScreenUpdates: true)
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
