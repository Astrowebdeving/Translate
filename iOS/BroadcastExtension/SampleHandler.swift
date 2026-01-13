//
//  SampleHandler.swift
//  BroadcastExtension
//
//  Broadcast Upload Extension that captures screen content and performs OCR
//  Runs as a separate process with strict 50MB memory limit
//

import ReplayKit
import Vision
import CoreImage

/// Broadcast Upload Extension handler for screen translation
/// Receives screen video stream, performs OCR, and writes results to App Group
class SampleHandler: RPBroadcastSampleHandler {
    
    // MARK: - Properties
    
    /// Throttling: Only process frames at this interval (seconds)
    private let processingInterval: TimeInterval = 1.0
    
    /// Last time we processed a frame
    private var lastProcessTime: Date = .distantPast
    
    /// Frame counter for status updates
    private var frameCount: Int = 0
    
    /// Vision text recognition request (reused for memory efficiency)
    private lazy var textRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleTextRecognition(request: request, error: error)
        }
        // Use .fast to stay within memory limits
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false  // Disable for speed/memory
        request.recognitionLanguages = ["en", "ja", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de"]
        return request
    }()
    
    /// Current screen size for bounding box calculations
    private var currentScreenSize: CGSize = .zero
    
    /// Pending text blocks for the current frame
    private var pendingTextBlocks: [ScreenTextBlock] = []
    
    /// CIContext for image processing (reused for memory efficiency)
    private lazy var ciContext: CIContext = {
        CIContext(options: [.useSoftwareRenderer: false])
    }()
    
    // MARK: - Lifecycle
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // Broadcast has started
        updateBroadcastStatus(.active)
        
        // Reset state
        frameCount = 0
        lastProcessTime = .distantPast
        
        // Log start (in debug builds only)
        #if DEBUG
        print("[BroadcastExtension] Started")
        #endif
    }
    
    override func broadcastPaused() {
        updateBroadcastStatus(.stopping)
    }
    
    override func broadcastResumed() {
        updateBroadcastStatus(.active)
    }
    
    override func broadcastFinished() {
        updateBroadcastStatus(.inactive)
        
        // Clean up
        clearSharedPayload()
        
        #if DEBUG
        print("[BroadcastExtension] Finished, processed \(frameCount) frames")
        #endif
    }
    
    // MARK: - Sample Buffer Processing
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            processVideoFrame(sampleBuffer)
        case .audioApp, .audioMic:
            // We don't process audio for translation
            break
        @unknown default:
            break
        }
    }
    
    /// Process a video frame from screen recording
    private func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        // Throttle: Only process at specified interval
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= processingInterval else {
            return
        }
        
        // Get pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        lastProcessTime = now
        frameCount += 1
        
        // Get dimensions
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        currentScreenSize = CGSize(width: width, height: height)
        
        // Perform OCR
        performOCR(on: pixelBuffer)
    }
    
    // MARK: - OCR Processing
    
    /// Perform text recognition on the pixel buffer
    private func performOCR(on pixelBuffer: CVPixelBuffer) {
        // Clear previous results
        pendingTextBlocks = []
        
        // Create request handler
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        
        do {
            try handler.perform([textRequest])
        } catch {
            #if DEBUG
            print("[BroadcastExtension] OCR error: \(error)")
            #endif
        }
    }
    
    /// Handle text recognition results
    private func handleTextRecognition(request: VNRequest, error: Error?) {
        guard error == nil else {
            #if DEBUG
            print("[BroadcastExtension] Recognition error: \(error!)")
            #endif
            return
        }
        
        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        // Process observations into text blocks
        var textBlocks: [ScreenTextBlock] = []
        var fullTextComponents: [String] = []
        var detectedLanguages: Set<String> = []
        
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else {
                continue
            }
            
            // Filter low confidence results
            guard topCandidate.confidence >= 0.5 else {
                continue
            }
            
            let language = detectLanguage(for: topCandidate.string)
            
            // Classify the text block based on position and size
            let blockType = classifyTextBlock(
                text: topCandidate.string,
                boundingBox: observation.boundingBox,
                screenSize: currentScreenSize
            )
            
            // Estimate font size from bounding box
            let estimatedFontSize = estimateFontSize(
                boundingBox: observation.boundingBox,
                screenSize: currentScreenSize
            )
            
            let block = ScreenTextBlock(
                text: topCandidate.string,
                confidence: topCandidate.confidence,
                boundingBox: observation.boundingBox,
                language: language,
                blockType: blockType,
                estimatedFontSize: estimatedFontSize
            )
            
            textBlocks.append(block)
            fullTextComponents.append(topCandidate.string)
            
            if let lang = language {
                detectedLanguages.insert(lang)
            }
        }
        
        // Only write if we found text
        guard !textBlocks.isEmpty else {
            return
        }
        
        // Sort by position (top to bottom, left to right)
        textBlocks.sort { block1, block2 in
            if abs(block1.boundingBox.maxY - block2.boundingBox.maxY) < 0.02 {
                return block1.boundingBox.minX < block2.boundingBox.minX
            }
            return block1.boundingBox.maxY > block2.boundingBox.maxY
        }
        
        // Create payload
        let payload = ScreenPayload(
            textBlocks: textBlocks,
            fullText: fullTextComponents.joined(separator: "\n"),
            detectedLanguages: Array(detectedLanguages),
            screenSize: currentScreenSize
        )
        
        // Write to shared container
        writePayload(payload)
    }
    
    // MARK: - Text Block Classification
    
    /// Classify a text block based on its position and size
    private func classifyTextBlock(
        text: String,
        boundingBox: CGRect,
        screenSize: CGSize
    ) -> TextBlockType {
        let normalizedHeight = boundingBox.height
        let normalizedWidth = boundingBox.width
        let normalizedY = boundingBox.minY  // Vision uses bottom-left origin
        
        // Estimate character count per line
        let textLength = text.count
        let isShortText = textLength < 20
        let isMediumText = textLength >= 20 && textLength < 100
        
        // Position-based heuristics (normalized coordinates 0-1)
        let isAtTop = normalizedY > 0.85  // Near top of screen
        let isAtBottom = normalizedY < 0.15  // Near bottom of screen
        
        // Size-based heuristics
        let isLarge = normalizedHeight > 0.05  // Large text (>5% of screen height)
        let isSmall = normalizedHeight < 0.025  // Small text (<2.5% of screen height)
        let isWide = normalizedWidth > 0.5  // Wide text block
        let isNarrow = normalizedWidth < 0.2  // Narrow text block
        
        // Classification logic
        if isAtTop && isLarge && isWide {
            return .header
        }
        
        if isAtBottom && isSmall {
            return .navigation
        }
        
        if isShortText && isNarrow && !isLarge {
            return .button
        }
        
        if isShortText && !isWide {
            return .label
        }
        
        if isMediumText || isWide {
            return .body
        }
        
        return .unknown
    }
    
    /// Estimate font size from bounding box height and screen size
    private func estimateFontSize(
        boundingBox: CGRect,
        screenSize: CGSize
    ) -> CGFloat {
        // Calculate pixel height of the bounding box
        let pixelHeight = boundingBox.height * screenSize.height
        
        // Approximate font size (font height is roughly 1.2x the point size)
        let estimatedSize = pixelHeight / 1.2
        
        // Clamp to reasonable range
        return min(max(estimatedSize, 8), 72)
    }
    
    // MARK: - Language Detection
    
    /// Simple character-based language detection
    private func detectLanguage(for text: String) -> String? {
        let japaneseSet = CharacterSet(charactersIn: "\u{3040}"..."\u{309F}")  // Hiragana
            .union(CharacterSet(charactersIn: "\u{30A0}"..."\u{30FF}"))  // Katakana
        let koreanSet = CharacterSet(charactersIn: "\u{AC00}"..."\u{D7AF}")  // Hangul
        let chineseSet = CharacterSet(charactersIn: "\u{4E00}"..."\u{9FFF}")  // CJK Unified
        
        let scalars = text.unicodeScalars
        var japaneseCount = 0
        var koreanCount = 0
        var chineseCount = 0
        var latinCount = 0
        
        for scalar in scalars {
            if japaneseSet.contains(scalar) {
                japaneseCount += 1
            } else if koreanSet.contains(scalar) {
                koreanCount += 1
            } else if chineseSet.contains(scalar) {
                chineseCount += 1
            } else if scalar.isASCII && scalar.properties.isAlphabetic {
                latinCount += 1
            }
        }
        
        let maxCount = max(japaneseCount, koreanCount, chineseCount, latinCount)
        
        if maxCount == 0 { return nil }
        
        if japaneseCount == maxCount { return "ja" }
        if koreanCount == maxCount { return "ko" }
        if chineseCount == maxCount { return "zh" }
        if latinCount == maxCount { return "en" }
        
        return nil
    }
    
    // MARK: - Shared Container Communication
    
    /// Write payload to shared App Group container
    private func writePayload(_ payload: ScreenPayload) {
        do {
            try AppGroupConstants.save(payload, to: AppGroupConstants.screenPayloadFileName)
            
            #if DEBUG
            print("[BroadcastExtension] Wrote payload with \(payload.textBlocks.count) blocks")
            #endif
        } catch {
            #if DEBUG
            print("[BroadcastExtension] Failed to write payload: \(error)")
            #endif
        }
    }
    
    /// Update broadcast status in shared container
    private func updateBroadcastStatus(_ state: BroadcastState, error: String? = nil) {
        let status = BroadcastStatus(state: state, frameCount: frameCount, errorMessage: error)
        
        do {
            try AppGroupConstants.save(status, to: "broadcast_status.json")
        } catch {
            #if DEBUG
            print("[BroadcastExtension] Failed to update status: \(error)")
            #endif
        }
    }
    
    /// Clear the shared payload file
    private func clearSharedPayload() {
        do {
            try AppGroupConstants.deleteFile(AppGroupConstants.screenPayloadFileName)
        } catch {
            #if DEBUG
            print("[BroadcastExtension] Failed to clear payload: \(error)")
            #endif
        }
    }
}
