//
//  TranslateLocalApp.swift
//  TranslateLocal
//
//  Main app entry point
//

import SwiftUI

@main
struct TranslateLocalApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.ocrService)
                .environmentObject(appState.translationService)
                .environmentObject(appState.modelManager)
        }
    }
}

// MARK: - App State

/// Global app state management
@MainActor
class AppState: ObservableObject {
    
    // MARK: - Services
    
    let ocrService: OCRService
    let translationService: TranslationService
    let modelManager: ModelManager
    
    // MARK: - Settings
    
    @Published var sourceLanguage: Language = .english
    @Published var targetLanguage: Language = .japanese
    @Published var autoDetectLanguage: Bool = true
    @Published var continuousTranslation: Bool = false
    @Published var hapticFeedback: Bool = true
    
    // MARK: - State
    
    @Published var isFirstLaunch: Bool
    @Published var hasCompletedOnboarding: Bool
    
    // MARK: - Initialization
    
    init() {
        self.modelManager = ModelManager.shared
        self.ocrService = OCRService()
        self.translationService = TranslationService(modelManager: modelManager)
        
        // Check first launch
        self.isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // Load saved settings
        loadSettings()
        
        // Mark as launched
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        if let sourceCode = UserDefaults.standard.string(forKey: "sourceLanguage"),
           let source = Language.from(code: sourceCode) {
            self.sourceLanguage = source
        }
        
        if let targetCode = UserDefaults.standard.string(forKey: "targetLanguage"),
           let target = Language.from(code: targetCode) {
            self.targetLanguage = target
        }
        
        self.autoDetectLanguage = UserDefaults.standard.object(forKey: "autoDetectLanguage") as? Bool ?? true
        self.continuousTranslation = UserDefaults.standard.bool(forKey: "continuousTranslation")
        self.hapticFeedback = UserDefaults.standard.object(forKey: "hapticFeedback") as? Bool ?? true
    }
    
    func saveSettings() {
        UserDefaults.standard.set(sourceLanguage.id, forKey: "sourceLanguage")
        UserDefaults.standard.set(targetLanguage.id, forKey: "targetLanguage")
        UserDefaults.standard.set(autoDetectLanguage, forKey: "autoDetectLanguage")
        UserDefaults.standard.set(continuousTranslation, forKey: "continuousTranslation")
        UserDefaults.standard.set(hapticFeedback, forKey: "hapticFeedback")
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    // MARK: - Translation Helpers
    
    func swapLanguages() {
        let temp = sourceLanguage
        sourceLanguage = targetLanguage
        targetLanguage = temp
        saveSettings()
    }
}
