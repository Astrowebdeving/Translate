//
//  ScreenTranslationService.swift
//  TranslateLocal
//
//  Service that coordinates screen translation by:
//  1. Watching the shared App Group file for OCR results from Broadcast Extension
//  2. Running translation on detected text
//  3. Updating the PiP display with translations
//

import Foundation
import Combine

/// Service for managing screen translation mode
@MainActor @Observable
class ScreenTranslationService {
    
    // MARK: - Observable Properties
    
    private(set) var isActive = false
    private(set) var broadcastState: BroadcastState = .inactive
    private(set) var lastPayload: ScreenPayload?
    private(set) var lastTranslation: ScreenTranslationResult?
    private(set) var error: ScreenTranslationError?
    private(set) var debugLog: String = ""
    
    /// Statistics
    private(set) var processedFrameCount = 0
    private(set) var translatedBlockCount = 0
    private(set) var lastCheckTime: Date?
    private(set) var fileExists: Bool = false
    
    /// Current positioned translations for overlay display
    private(set) var positionedTranslations: [PositionedTranslation] = []
    
    /// Whether overlay mode is enabled
    private(set) var isOverlayEnabled = false
    
    /// Whether smart positioning with Gemma is enabled
    var useSmartPositioning = true
    
    // MARK: - Services
    
    private let pipService: PiPService
    private let translationService: TranslationService
    
    // MARK: - Configuration
    
    var sourceLanguage: Language = .english
    var targetLanguage: Language = .japanese
    var processingInterval: TimeInterval = 1.0
    var overlayOpacity: Float = 0.3
    
    // MARK: - Feature Availability
    
    /// Check if overlay feature is available (real device only)
    var isOverlayFeatureAvailable: Bool {
        return pipService.isOverlayFeatureAvailable
    }
    
    // MARK: - Private Properties
    
    /// File monitoring timer
    private var fileWatchTimer: Timer?
    
    /// Last processed payload ID to avoid reprocessing
    private var lastProcessedPayloadId: UUID?
    
    /// Last file modification date
    private var lastFileModDate: Date?
    
    /// Translation task
    private var translationTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(translationService: TranslationService) {
        self.translationService = translationService
        self.pipService = PiPService()
        DebugLogger.screenTranslation("ScreenTranslationService initialized", level: .info)
        addDebugLog("Service initialized")
    }
    
    // MARK: - Debug Helpers
    
    private func addDebugLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(timestamp)] \(message)"
        debugLog = line + "\n" + debugLog
        // Keep only last 20 lines
        let lines = debugLog.components(separatedBy: "\n")
        if lines.count > 20 {
            debugLog = lines.prefix(20).joined(separator: "\n")
        }
    }
    
    // MARK: - Public Methods
    
    /// Get PiP service for status display
    var pipStatus: String {
        return pipService.statusMessage
    }
    
    var pipFrameCount: Int {
        return pipService.frameCount
    }
    
    #if targetEnvironment(simulator)
    /// Start demo mode for simulator testing
    func startDemoMode() {
        pipService.startDemoMode()
        addDebugLog("Demo mode started")
    }
    
    /// Stop demo mode
    func stopDemoMode() {
        pipService.stopDemoMode()
        addDebugLog("Demo mode stopped")
    }
    #endif
    
    // MARK: - Overlay Control
    
    /// Toggle overlay mode on/off
    func toggleOverlay() {
        isOverlayEnabled.toggle()
        pipService.toggleOverlay()
        
        if isOverlayEnabled {
            addDebugLog("Overlay enabled")
            DebugLogger.screenTranslation("Overlay mode enabled", level: .info)
        } else {
            addDebugLog("Overlay disabled")
            positionedTranslations = []
            DebugLogger.screenTranslation("Overlay mode disabled", level: .info)
        }
    }
    
    /// Set overlay opacity
    func setOverlayOpacity(_ opacity: Float) {
        overlayOpacity = opacity
        pipService.setOverlayOpacity(Double(opacity))
    }
    
    /// Get current overlay mode
    var overlayMode: OverlayMode {
        return pipService.overlayMode
    }
    
    /// Start screen translation mode
    func start() async throws {
        guard !isActive else {
            addDebugLog("Already active, ignoring start")
            return
        }
        
        DebugLogger.screenTranslation("Starting screen translation mode", level: .info)
        addDebugLog("Starting screen translation...")
        
        // Reset state
        processedFrameCount = 0
        translatedBlockCount = 0
        lastProcessedPayloadId = nil
        lastFileModDate = nil
        error = nil
        
        // Check App Group access
        if let containerURL = AppGroupConstants.sharedContainerURL {
            addDebugLog("App Group container: \(containerURL.lastPathComponent)")
            DebugLogger.screenTranslation("App Group container: \(containerURL.path)", level: .success)
        } else {
            addDebugLog("ERROR: No App Group container!")
            DebugLogger.screenTranslation("App Group container not accessible!", level: .error)
        }
        
        // Save settings to shared container for extension to read
        saveSharedSettings()
        addDebugLog("Settings saved to shared container")
        
        // Start PiP
        do {
            addDebugLog("Starting PiP...")
            try await pipService.startPiP()
            pipService.showWaiting()
            addDebugLog("PiP started successfully")
        } catch {
            addDebugLog("PiP failed: \(error.localizedDescription)")
            DebugLogger.screenTranslation("PiP failed: \(error)", level: .error)
            throw ScreenTranslationError.pipFailed(error.localizedDescription)
        }
        
        // Start file watching
        startFileWatching()
        addDebugLog("File watching started")
        
        isActive = true
        DebugLogger.screenTranslation("Screen translation mode active", level: .success)
    }
    
    /// Stop screen translation mode
    func stop() {
        DebugLogger.screenTranslation("Stopping screen translation mode", level: .info)
        addDebugLog("Stopping...")
        
        isActive = false
        
        // Stop file watching
        stopFileWatching()
        
        // Stop PiP
        pipService.stopPiP()
        
        // Cancel any pending translation
        translationTask?.cancel()
        translationTask = nil
        
        // Update shared settings
        var settings = ScreenModeSettings.load()
        settings.isActive = false
        try? settings.save()
        
        addDebugLog("Stopped")
    }
    
    /// Update language settings
    func updateLanguages(source: Language, target: Language) {
        sourceLanguage = source
        targetLanguage = target
        saveSharedSettings()
    }
    
    /// Get instructions for starting broadcast
    func getBroadcastInstructions() -> String {
        return """
        To start screen translation:
        
        1. Open Control Center (swipe down from top-right)
        2. Long-press the Screen Recording button
        3. Select "TranslateLocal Screen" from the list
        4. Tap "Start Broadcast"
        
        The translation will appear in the floating window.
        """
    }
    
    // MARK: - Private Methods
    
    private func saveSharedSettings() {
        var settings = ScreenModeSettings(
            isActive: isActive,
            sourceLanguageCode: sourceLanguage.id,
            targetLanguageCode: targetLanguage.id,
            processingInterval: processingInterval,
            showOriginalText: true,
            overlayOpacity: 0.9,
            fontSize: 16,
            lastUpdated: Date()
        )
        
        try? settings.save()
    }
    
    // MARK: - File Watching
    
    private func startFileWatching() {
        stopFileWatching()
        
        // Check for updates at processing interval
        fileWatchTimer = Timer.scheduledTimer(withTimeInterval: processingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkForUpdates()
            }
        }
    }
    
    private func stopFileWatching() {
        fileWatchTimer?.invalidate()
        fileWatchTimer = nil
    }
    
    /// Check for new OCR data from the broadcast extension
    private func checkForUpdates() async {
        lastCheckTime = Date()
        
        // Check broadcast status first
        await updateBroadcastStatus()
        
        // Check if file exists
        fileExists = AppGroupConstants.fileExists(AppGroupConstants.screenPayloadFileName)
        
        // Check if file has been modified
        guard let modDate = AppGroupConstants.fileModificationDate(AppGroupConstants.screenPayloadFileName) else {
            // No file yet - extension hasn't written anything
            if broadcastState == .active {
                broadcastState = .starting
            }
            return
        }
        
        // Skip if we've already processed this version
        if let lastMod = lastFileModDate, modDate <= lastMod {
            return
        }
        
        lastFileModDate = modDate
        addDebugLog("New file detected, modified: \(modDate)")
        DebugLogger.screenTranslation("New payload file detected", level: .info)
        
        // Load the payload
        do {
            let payload = try AppGroupConstants.load(ScreenPayload.self, from: AppGroupConstants.screenPayloadFileName)
            
            // Skip if we've already processed this payload
            guard payload.id != lastProcessedPayloadId else {
                return
            }
            
            lastPayload = payload
            lastProcessedPayloadId = payload.id
            processedFrameCount += 1
            
            addDebugLog("Payload loaded: \(payload.textBlocks.count) text blocks")
            DebugLogger.screenTranslation("Loaded payload with \(payload.textBlocks.count) text blocks", level: .success)
            
            // Update broadcast state
            broadcastState = .active
            
            // Process the payload
            await processPayload(payload)
            
        } catch {
            addDebugLog("Failed to load payload: \(error.localizedDescription)")
            DebugLogger.screenTranslation("Failed to load payload: \(error)", level: .error)
        }
    }
    
    /// Update broadcast status from shared file
    private func updateBroadcastStatus() async {
        do {
            let status = try AppGroupConstants.load(BroadcastStatus.self, from: "broadcast_status.json")
            
            // Check if status is stale (more than 5 seconds old)
            if Date().timeIntervalSince(status.timestamp) > 5.0 && broadcastState == .active {
                broadcastState = .inactive
                pipService.showWaiting()
            } else {
                broadcastState = status.state
            }
            
        } catch {
            // Status file doesn't exist - broadcast not started
            if broadcastState != .inactive {
                broadcastState = .inactive
            }
        }
    }
    
    // MARK: - Translation Processing
    
    /// Process a new OCR payload
    private func processPayload(_ payload: ScreenPayload) async {
        guard !payload.textBlocks.isEmpty else {
            // No text found - show message in PiP
            pipService.updateContent("No text detected on screen")
            return
        }
        
        // Cancel any existing translation
        translationTask?.cancel()
        
        // Start new translation
        translationTask = Task {
            await translatePayload(payload)
        }
    }
    
    /// Translate the text blocks in a payload
    private func translatePayload(_ payload: ScreenPayload) async {
        guard !payload.textBlocks.isEmpty else {
            addDebugLog("No text blocks, skipping translation")
            return
        }
        
        let textToTranslate = payload.fullText
        
        guard !textToTranslate.isEmpty else {
            addDebugLog("Empty text, skipping translation")
            return
        }
        
        addDebugLog("Translating \(payload.textBlocks.count) blocks: \(truncate(textToTranslate, maxLength: 30))")
        DebugLogger.screenTranslation("Translating \(payload.textBlocks.count) text blocks", level: .info)
        
        // Show that we're translating
        pipService.updateContent("Translating...", originalText: truncate(textToTranslate, maxLength: 50))
        
        do {
            // Use positioned translation if overlay mode is enabled and Gemma is available
            if isOverlayEnabled && useSmartPositioning {
                // Smart positioning with Gemma
                let positioned = try await translationService.translateWithPositioning(
                    textBlocks: payload.textBlocks,
                    from: sourceLanguage,
                    to: targetLanguage,
                    screenSize: payload.screenSize
                )
                
                guard !Task.isCancelled else { return }
                
                positionedTranslations = positioned
                pipService.updatePositionedTranslations(positioned)
                
                addDebugLog("Smart translation done: \(positioned.count) positioned blocks")
                DebugLogger.screenTranslation("Smart positioning complete: \(positioned.count) blocks", level: .success)
                
                translatedBlockCount += positioned.count
                
            } else {
                // Simple translation mode
                let result = try await translationService.translate(
                    text: textToTranslate,
                    from: sourceLanguage,
                    to: targetLanguage
                )
                
                guard !Task.isCancelled else { return }
                
                addDebugLog("Translation done: \(truncate(result.translatedText, maxLength: 30))")
                DebugLogger.screenTranslation("Translation complete", level: .success)
                
                // Update PiP with translation
                pipService.updateContent(
                    result.translatedText,
                    originalText: truncate(textToTranslate, maxLength: 50)
                )
                
                translatedBlockCount += 1
            }
            
            // Create translation result for sharing
            let translations: [String: TranslatedBlock] = [
                "main": TranslatedBlock(
                    originalText: textToTranslate,
                    translatedText: positionedTranslations.map(\.translatedText).joined(separator: "\n"),
                    sourceLanguage: sourceLanguage.id,
                    targetLanguage: targetLanguage.id,
                    confidence: 0.9
                )
            ]
            
            let translationResult = ScreenTranslationResult(
                payloadId: payload.id,
                translations: translations,
                status: .completed
            )
            
            lastTranslation = translationResult
            
            // Save to shared container
            try? AppGroupConstants.save(translationResult, to: AppGroupConstants.translationResultFileName)
            
        } catch {
            guard !Task.isCancelled else { return }
            
            addDebugLog("Translation error: \(error.localizedDescription)")
            DebugLogger.screenTranslation("Translation failed: \(error)", level: .error)
            pipService.showError("Translation failed: \(error.localizedDescription)")
            self.error = .translationFailed(error.localizedDescription)
        }
    }
    
    /// Truncate text for display
    private func truncate(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength)) + "..."
    }
}

// MARK: - Errors

enum ScreenTranslationError: LocalizedError {
    case pipFailed(String)
    case broadcastNotStarted
    case translationFailed(String)
    case noTextDetected
    
    var errorDescription: String? {
        switch self {
        case .pipFailed(let reason):
            return "PiP failed: \(reason)"
        case .broadcastNotStarted:
            return "Screen broadcast has not been started"
        case .translationFailed(let reason):
            return "Translation failed: \(reason)"
        case .noTextDetected:
            return "No text was detected on screen"
        }
    }
}
