//
//  AppleTranslationService.swift
//  TranslateLocal
//
//  Uses Apple's built-in Translation framework for on-device translation
//  This is one of multiple local translation options
//

import Foundation
import SwiftUI

// Only import Translation framework if available (iOS 18+)
#if canImport(Translation)
import Translation
#endif

// MARK: - Apple Translation Service

/// Service that uses Apple's built-in Translation framework
/// Provides real on-device translation using system language packs
/// Only available on iOS 18.0 and later
@available(iOS 18.0, *)
@MainActor @Observable
class AppleTranslationService {
    
    // MARK: - Observable Properties
    
    private(set) var isTranslating = false
    private(set) var error: AppleTranslationError?
    private(set) var downloadedLanguages: Set<String> = []
    
    // MARK: - Private Properties

    // Note: TranslationSession doesn't maintain language state - each translate call handles languages
    
    // MARK: - Initialization
    
    init() {
        Task {
            await checkAvailableLanguages()
        }
    }
    
    // MARK: - Language Availability
    
    /// Check which languages are downloaded and available
    func checkAvailableLanguages() async {
        let languagesToCheck = ["en", "es", "zh", "ja", "ko", "fr", "de", "it", "pt", "ru", "ar"]
        var downloaded: Set<String> = []
        
        for langCode in languagesToCheck {
            let locale = Locale.Language(identifier: langCode)
            let availability = LanguageAvailability()
            
            // Check if this language can translate to/from English
            let status = await availability.status(
                from: locale,
                to: Locale.Language(identifier: "en")
            )
            
            if status == .installed {
                downloaded.insert(langCode)
            }
        }
        
        // English is always available
        downloaded.insert("en")
        self.downloadedLanguages = downloaded
    }
    
    /// Check if a language pair is available (downloaded for offline use)
    func isAvailable(from source: String, to target: String) async -> Bool {
        let sourceLocale = Locale.Language(identifier: mapLanguageCode(source))
        let targetLocale = Locale.Language(identifier: mapLanguageCode(target))
        
        let availability = LanguageAvailability()
        let status = await availability.status(from: sourceLocale, to: targetLocale)
        
        return status == .installed || status == .supported
    }
    
    // MARK: - Translation
    
    /// Translate text using Apple's Translation framework
    func translate(
        text: String,
        from sourceLanguageCode: String,
        to targetLanguageCode: String
    ) async throws -> String {
        guard !text.isEmpty else {
            throw AppleTranslationError.emptyInput
        }

        isTranslating = true
        error = nil

        defer { isTranslating = false }

        do {
            let sourceLocale = Locale.Language(identifier: mapLanguageCode(sourceLanguageCode))
            let targetLocale = Locale.Language(identifier: mapLanguageCode(targetLanguageCode))

            // Check availability - must be installed for translation
            let availability = LanguageAvailability()
            let status = await availability.status(from: sourceLocale, to: targetLocale)

            guard status == .installed else {
                throw AppleTranslationError.languageNotAvailable(sourceLanguageCode, targetLanguageCode)
            }

            // Use SwiftUI helper to perform translation (TranslationSession only available via .translationTask)
            return try await performTranslationWithSwiftUI(text: text, source: sourceLocale, target: targetLocale)

        } catch let error as AppleTranslationError {
            self.error = error
            throw error
        } catch {
            let translationError = AppleTranslationError.translationFailed(error.localizedDescription)
            self.error = translationError
            throw translationError
        }
    }

    /// Note: Apple's Translation API in iOS 18 requires SwiftUI's .translationTask modifier
    /// This service provides language availability checking but actual translation
    /// should be performed in SwiftUI views using .translationTask
    private func performTranslationWithSwiftUI(text: String, source: Locale.Language, target: Locale.Language) async throws -> String {
        // Placeholder implementation - proper translation requires SwiftUI .translationTask modifier
        // The actual implementation should be done in SwiftUI views like this:
        //
        // .translationTask(.init(source: source, target: target)) { session in
        //     let response = try await session.translate(text)
        //     // handle response
        // }

        throw AppleTranslationError.translationFailed("Apple Translation requires SwiftUI integration. Use .translationTask modifier in views.")
    }
    
    /// Map our language codes to Apple's expected format
    private func mapLanguageCode(_ code: String) -> String {
        switch code {
        case "zh": return "zh-Hans"  // Simplified Chinese
        default: return code
        }
    }
    
    /// Reset any cached state (iOS 18 doesn't maintain session state)
    func invalidateSession() {
        // No persistent session state to clean up in iOS 18 API
    }
}

// MARK: - Translation Helper

/// SwiftUI helper to access TranslationSession via .translationTask modifier
@available(iOS 18.0, *)
private struct TranslationHelper: View {
    let text: String
    let source: Locale.Language
    let target: Locale.Language
    let completion: (Result<String, Error>) -> Void

    @State private var result: String?

    var body: some View {
        Color.clear // Invisible view
            .frame(width: 0, height: 0)
            .translationTask(.init(source: source, target: target)) { session in
                do {
                    let response = try await session.translate(text)
                    completion(.success(response.targetText))
                } catch {
                    completion(.failure(error))
                }
            }
    }
}

// MARK: - Error Types

enum AppleTranslationError: LocalizedError {
    case emptyInput
    case languageNotAvailable(String, String)
    case sessionFailed
    case translationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Input text is empty"
        case .languageNotAvailable(let source, let target):
            return "Translation from \(source) to \(target) not available. Download language pack in Settings."
        case .sessionFailed:
            return "Failed to create translation session"
        case .translationFailed(let reason):
            return "Translation failed: \(reason)"
        }
    }
}
