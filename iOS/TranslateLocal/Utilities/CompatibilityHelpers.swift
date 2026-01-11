//
//  CompatibilityHelpers.swift
//  TranslateLocal
//
//  Backward compatibility utilities for supporting multiple iOS versions
//  Primary target: iOS 26.2+
//  Backward compatibility: iOS 17.0+
//

import Foundation
import UIKit
import SwiftUI
import Vision
import CoreML

// MARK: - iOS Version Detection

/// Helper to check iOS version for backward compatibility
struct iOSVersion {
    static let current = UIDevice.current.systemVersion
    
    /// iOS 26+ features
    static var is26OrLater: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }
    
    /// iOS 18+ features
    static var is18OrLater: Bool {
        if #available(iOS 18, *) {
            return true
        }
        return false
    }
    
    /// iOS 17+ (minimum supported)
    static var is17OrLater: Bool {
        if #available(iOS 17, *) {
            return true
        }
        return false
    }
    
    /// Check for Neural Engine availability (A12+ chips)
    static var hasNeuralEngine: Bool {
        // Neural Engine is available on A12 Bionic and later
        // This is a proxy check - we assume any device running iOS 17+ has it
        return is17OrLater
    }
    
    /// Recommended compute units based on device capabilities
    static var recommendedComputeUnits: MLComputeUnits {
        if hasNeuralEngine {
            return .all  // Use Neural Engine when available
        }
        return .cpuAndGPU
    }
}

// MARK: - Vision Framework Compatibility

/// Vision framework compatibility wrapper
@MainActor
class VisionCompatibility {
    
    /// Supported recognition languages with version checks
    static func supportedLanguages() -> [String] {
        do {
            // Try the most recent API first
            if #available(iOS 16, *) {
                let revision = VNRecognizeTextRequest.currentRevision
                return try VNRecognizeTextRequest.supportedRecognitionLanguages(
                    for: .accurate,
                    revision: revision
                )
            } else {
                // Fallback for older iOS versions
                return ["en", "fr", "de", "es", "pt", "it", "zh-Hans", "zh-Hant", "ja", "ko"]
            }
        } catch {
            // Default set if query fails
            return ["en", "ja", "zh-Hans", "zh-Hant", "ko", "es", "fr", "de"]
        }
    }
    
    /// Create a text recognition request with optimal settings for the current iOS version
    static func createTextRecognitionRequest(
        languages: [String],
        completion: @escaping ([VNRecognizedTextObservation]?, Error?) -> Void
    ) -> VNRecognizeTextRequest {
        
        let request = VNRecognizeTextRequest { request, error in
            let observations = request.results as? [VNRecognizedTextObservation]
            completion(observations, error)
        }
        
        // Configure based on iOS version capabilities
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Set recognition languages
        request.recognitionLanguages = languages
        
        // Use automatic language detection if available
        if #available(iOS 16, *) {
            request.automaticallyDetectsLanguage = true
        }
        
        return request
    }
}

// MARK: - Core ML Compatibility

/// Core ML configuration optimized for device capabilities
struct CoreMLCompatibility {
    
    /// Create optimized ML model configuration
    static func createModelConfiguration() -> MLModelConfiguration {
        let config = MLModelConfiguration()
        
        // Use all available compute units (CPU, GPU, Neural Engine)
        config.computeUnits = iOSVersion.recommendedComputeUnits
        
        // Allow low precision for better performance on Neural Engine
        if #available(iOS 16, *) {
            config.allowLowPrecisionAccumulationOnGPU = true
        }
        
        return config
    }
    
    /// Load model with error handling and fallback
    static func loadModel(
        named name: String,
        bundle: Bundle = .main
    ) async throws -> MLModel {
        
        let config = createModelConfiguration()
        
        // Try to find the model
        guard let modelURL = findModelURL(named: name, in: bundle) else {
            throw CoreMLError.modelNotFound(name)
        }
        
        // Load with configuration
        return try await MLModel.load(contentsOf: modelURL, configuration: config)
    }
    
    private static func findModelURL(named name: String, in bundle: Bundle) -> URL? {
        // Check for compiled model first (.mlmodelc)
        if let url = bundle.url(forResource: name, withExtension: "mlmodelc") {
            return url
        }
        
        // Check for package (.mlpackage)
        if let url = bundle.url(forResource: name, withExtension: "mlpackage") {
            return url
        }
        
        // Check in Documents directory (for downloaded models)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let documentsURL = documentsPath.appendingPathComponent("\(name).mlmodelc")
        if FileManager.default.fileExists(atPath: documentsURL.path) {
            return documentsURL
        }
        
        // Check in App Group container (for sharing with extensions)
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.translatelocal.shared") {
            let sharedURL = containerURL.appendingPathComponent("Models/\(name).mlmodelc")
            if FileManager.default.fileExists(atPath: sharedURL.path) {
                return sharedURL
            }
        }
        
        return nil
    }
    
    enum CoreMLError: LocalizedError {
        case modelNotFound(String)
        case loadFailed(String, String)
        
        var errorDescription: String? {
            switch self {
            case .modelNotFound(let name):
                return "Model '\(name)' not found in bundle or documents"
            case .loadFailed(let name, let reason):
                return "Failed to load '\(name)': \(reason)"
            }
        }
    }
}

// MARK: - SwiftUI Compatibility

/// SwiftUI compatibility extensions
extension View {
    
    /// Apply navigation title with backward compatibility
    @ViewBuilder
    func compatibleNavigationTitle(_ title: String) -> some View {
        if #available(iOS 17, *) {
            self.navigationTitle(title)
        } else {
            self.navigationBarTitle(title)
        }
    }
    
    /// Apply sheet presentation with detents (iOS 16+) or regular sheet
    @ViewBuilder
    func compatibleSheet<Content: View>(
        isPresented: Binding<Bool>,
        detents: [UISheetPresentationController.Detent]? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if #available(iOS 16, *), let detents = detents {
            self.sheet(isPresented: isPresented) {
                content()
                    .presentationDetents(Set(detents.map { detent in
                        if detent == .medium() {
                            return .medium
                        } else if detent == .large() {
                            return .large
                        }
                        return .large
                    }))
            }
        } else {
            self.sheet(isPresented: isPresented, content: content)
        }
    }
    
    /// Apply material background with fallback
    @ViewBuilder
    func compatibleMaterialBackground() -> some View {
        if #available(iOS 15, *) {
            self.background(.ultraThinMaterial)
        } else {
            self.background(Color.black.opacity(0.7))
        }
    }
}

// MARK: - Camera Compatibility

/// Camera session compatibility for different iOS versions
struct CameraCompatibility {
    
    /// Check camera authorization with async/await (iOS 15+) or completion handler
    static func checkAuthorization() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
    
    /// Get best available camera device
    static func getPreferredCamera() -> AVCaptureDevice? {
        // Try to get the best wide angle camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return device
        }
        
        // Fallback to any available camera
        return AVCaptureDevice.default(for: .video)
    }
    
    /// Configure video output with optimal settings
    static func configureVideoOutput(_ output: AVCaptureVideoDataOutput) {
        output.alwaysDiscardsLateVideoFrames = true
        
        // Use BGRA format for compatibility with Vision and Core ML
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
    }
}

// MARK: - App Group Shared Storage

/// Utilities for sharing data between main app and extensions
class SharedStorage {
    
    static let appGroupIdentifier = "group.com.translatelocal.shared"
    
    /// Get the shared container URL
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }
    
    /// Shared UserDefaults for settings sync between app and extensions
    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    /// Path for shared models
    static var modelsDirectory: URL? {
        containerURL?.appendingPathComponent("Models", isDirectory: true)
    }
    
    /// Create shared directories if needed
    static func setupSharedDirectories() {
        guard let modelsDir = modelsDirectory else { return }
        
        try? FileManager.default.createDirectory(
            at: modelsDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    /// Copy model to shared location for extension access
    static func shareModel(at sourceURL: URL, named name: String) throws {
        guard let modelsDir = modelsDirectory else {
            throw SharedStorageError.containerNotAvailable
        }
        
        let destinationURL = modelsDir.appendingPathComponent(name)
        
        // Remove existing if present
        try? FileManager.default.removeItem(at: destinationURL)
        
        // Copy to shared location
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }
    
    enum SharedStorageError: LocalizedError {
        case containerNotAvailable
        
        var errorDescription: String? {
            switch self {
            case .containerNotAvailable:
                return "App Group container is not available"
            }
        }
    }
}

// MARK: - Device Info

/// Device information for adaptive UI and model selection
struct DeviceInfo {
    
    /// Available RAM in bytes
    static var availableMemory: UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return ProcessInfo.processInfo.physicalMemory - info.resident_size
        }
        
        return ProcessInfo.processInfo.physicalMemory / 2  // Estimate
    }
    
    /// Total device RAM
    static var totalMemory: UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }
    
    /// Check if device can run large models (6GB+ RAM)
    static var canRunLargeModels: Bool {
        totalMemory >= 6 * 1024 * 1024 * 1024  // 6GB
    }
    
    /// Check if device is iPad
    static var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    /// Recommended model size based on device
    static var recommendedModelSize: ModelSize {
        if totalMemory >= 8 * 1024 * 1024 * 1024 {
            return .large  // 8GB+ devices can run Gemma-3n
        } else if totalMemory >= 6 * 1024 * 1024 * 1024 {
            return .medium  // 6GB devices can run medium models
        } else {
            return .small  // Use Opus-MT pairs for older devices
        }
    }
    
    enum ModelSize {
        case small   // Opus-MT pairs (~50-300MB each)
        case medium  // Smaller multilingual models
        case large   // Gemma-3n (~800MB)
    }
}

// MARK: - Import for AVFoundation
import AVFoundation
