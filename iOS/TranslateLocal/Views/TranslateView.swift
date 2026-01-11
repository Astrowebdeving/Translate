//
//  TranslateView.swift
//  TranslateLocal
//
//  Unified translation view with local AI and cloud API options
//

import SwiftUI

// MARK: - Translation Mode

enum TranslationMode: String, CaseIterable {
    case apple = "Apple"
    case customAI = "AI Models"
    case cloud = "Cloud"
    
    var icon: String {
        switch self {
        case .apple: return "apple.logo"
        case .customAI: return "cpu"
        case .cloud: return "cloud"
        }
    }
    
    var color: Color {
        switch self {
        case .apple: return .blue
        case .customAI: return .indigo
        case .cloud: return .green
        }
    }
    
    var description: String {
        switch self {
        case .apple: return "Apple's built-in translation (download via Settings)"
        case .customAI: return "Custom CoreML models (Opus-MT, Gemma)"
        case .cloud: return "Cloud APIs (Google, OpenAI, DeepL)"
        }
    }
}

// MARK: - Cloud Translation Provider

enum CloudProvider: String, CaseIterable, Identifiable {
    case googleTranslate = "Google Translate"
    case gemini = "Gemini Pro"
    case openAI = "ChatGPT"
    case deepL = "DeepL"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .googleTranslate: return "g.circle.fill"
        case .gemini: return "sparkles"
        case .openAI: return "brain.head.profile"
        case .deepL: return "text.bubble"
        }
    }
    
    var color: Color {
        switch self {
        case .googleTranslate: return .blue
        case .gemini: return .purple
        case .openAI: return .green
        case .deepL: return .indigo
        }
    }
    
    var description: String {
        switch self {
        case .googleTranslate: return "Fast, reliable translation"
        case .gemini: return "AI with nuanced understanding"
        case .openAI: return "GPT-4 powered translation"
        case .deepL: return "High-quality translation"
        }
    }
    
    var apiKeyName: String {
        switch self {
        case .googleTranslate: return "Google Cloud API Key"
        case .gemini: return "Gemini API Key"
        case .openAI: return "OpenAI API Key"
        case .deepL: return "DeepL API Key"
        }
    }
}

// MARK: - Cloud Translation Service

@MainActor @Observable
class CloudTranslationService {
    var isTranslating = false
    var error: String?
    var lastTranslation: String = ""
    
    // API Keys (stored in UserDefaults - in production use Keychain)
    var googleAPIKey: String {
        get { UserDefaults.standard.string(forKey: "googleAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "googleAPIKey") }
    }
    
    var geminiAPIKey: String {
        get { UserDefaults.standard.string(forKey: "geminiAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "geminiAPIKey") }
    }
    
    var openAIAPIKey: String {
        get { UserDefaults.standard.string(forKey: "openAIAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "openAIAPIKey") }
    }
    
    var deepLAPIKey: String {
        get { UserDefaults.standard.string(forKey: "deepLAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "deepLAPIKey") }
    }
    
    func getAPIKey(for provider: CloudProvider) -> String {
        switch provider {
        case .googleTranslate: return googleAPIKey
        case .gemini: return geminiAPIKey
        case .openAI: return openAIAPIKey
        case .deepL: return deepLAPIKey
        }
    }
    
    func setAPIKey(_ key: String, for provider: CloudProvider) {
        switch provider {
        case .googleTranslate: googleAPIKey = key
        case .gemini: geminiAPIKey = key
        case .openAI: openAIAPIKey = key
        case .deepL: deepLAPIKey = key
        }
    }
    
    func translate(
        text: String,
        from sourceLanguage: Language,
        to targetLanguage: Language,
        using provider: CloudProvider
    ) async throws -> String {
        let apiKey = getAPIKey(for: provider)
        guard !apiKey.isEmpty else {
            throw CloudTranslationError.noAPIKey
        }
        
        isTranslating = true
        error = nil
        
        defer { isTranslating = false }
        
        do {
            let result: String
            
            switch provider {
            case .googleTranslate:
                result = try await translateWithGoogle(text: text, from: sourceLanguage, to: targetLanguage, apiKey: apiKey)
            case .gemini:
                result = try await translateWithGemini(text: text, from: sourceLanguage, to: targetLanguage, apiKey: apiKey)
            case .openAI:
                result = try await translateWithOpenAI(text: text, from: sourceLanguage, to: targetLanguage, apiKey: apiKey)
            case .deepL:
                result = try await translateWithDeepL(text: text, from: sourceLanguage, to: targetLanguage, apiKey: apiKey)
            }
            
            lastTranslation = result
            return result
            
        } catch {
            self.error = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Google Translate API
    
    private func translateWithGoogle(text: String, from source: Language, to target: Language, apiKey: String) async throws -> String {
        let urlString = "https://translation.googleapis.com/language/translate/v2?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw CloudTranslationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "q": text,
            "source": source.id,
            "target": target.id,
            "format": "text"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CloudTranslationError.apiError("Google API error")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let translations = (json?["data"] as? [String: Any])?["translations"] as? [[String: Any]]
        
        guard let translatedText = translations?.first?["translatedText"] as? String else {
            throw CloudTranslationError.parseError
        }
        
        return translatedText
    }
    
    // MARK: - Gemini API
    
    private func translateWithGemini(text: String, from source: Language, to target: Language, apiKey: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw CloudTranslationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let prompt = """
        Translate the following text from \(source.name) to \(target.name). 
        Only respond with the translation, no explanations.
        
        Text: \(text)
        """
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 2048
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CloudTranslationError.apiError("Gemini API error")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        
        guard let translatedText = parts?.first?["text"] as? String else {
            throw CloudTranslationError.parseError
        }
        
        return translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - OpenAI API
    
    private func translateWithOpenAI(text: String, from source: Language, to target: Language, apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw CloudTranslationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a professional translator. Translate the user's text from \(source.name) to \(target.name). Only respond with the translation, nothing else."
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ],
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CloudTranslationError.apiError("OpenAI API error")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        
        guard let translatedText = message?["content"] as? String else {
            throw CloudTranslationError.parseError
        }
        
        return translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - DeepL API
    
    private func translateWithDeepL(text: String, from source: Language, to target: Language, apiKey: String) async throws -> String {
        guard let url = URL(string: "https://api-free.deepl.com/v2/translate") else {
            throw CloudTranslationError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let targetLang = target.id.uppercased()
        let body = "text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text)&target_lang=\(targetLang)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CloudTranslationError.apiError("DeepL API error")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let translations = json?["translations"] as? [[String: Any]]
        
        guard let translatedText = translations?.first?["text"] as? String else {
            throw CloudTranslationError.parseError
        }
        
        return translatedText
    }
}

enum CloudTranslationError: LocalizedError {
    case noAPIKey
    case invalidURL
    case apiError(String)
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No API key configured. Add your API key in settings."
        case .invalidURL: return "Invalid API URL"
        case .apiError(let msg): return msg
        case .parseError: return "Failed to parse API response"
        }
    }
}

// MARK: - Translate View

@available(iOS 18.0, *)
struct TranslateView: View {
    @Environment(AppState.self) var appState
    @State private var cloudService = CloudTranslationService()
    @State private var coreMLDownloader = CoreMLModelDownloader()

    // Apple service available on iOS 18+
    @State private var appleService: AppleTranslationService?

    // Initialize Apple service
    private var appleTranslationService: AppleTranslationService? {
        if appleService == nil {
            appleService = AppleTranslationService()
        }
        return appleService
    }
    @State private var glossaryService = GlossaryService()
    
    @State private var sourceText: String = ""
    @State private var translatedText: String = ""
    @State private var translationMode: TranslationMode = .customAI
    @State private var selectedProvider: CloudProvider = .googleTranslate
    
    @State private var showingAPIKeySheet = false
    @State private var showingProviderPicker = false
    @State private var showingModelDownloader = false
    @State private var showingAppleLanguages = false
    @State private var isTranslating = false
    @State private var translationError: String?
    @State private var useGlossary = true
    @State private var appliedGlossaryEntries: [GlossaryEntry] = []
    
    private var availableModelCount: Int {
        coreMLDownloader.downloadedModels.count
    }
    
    private var appleLanguageCount: Int {
        return appleTranslationService?.downloadedLanguages.count ?? 0
    }
    
    private var glossaryEntryCount: Int {
        glossaryService.enabledEntries
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Mode Toggle
                    modeToggle
                    
                    // Mode-specific content
                    switch translationMode {
                    case .apple:
                        appleModeContent
                    case .customAI:
                        customAIModeContent
                    case .cloud:
                        cloudModeContent
                    }
                    
                    // Source Text Input
                    sourceTextCard
                    
                    // Translate Button
                    translateButton
                    
                    // Translation Result
                    if translationMode == .apple && !sourceText.isEmpty {
                        AppleTranslationView(textToTranslate: sourceText)
                    } else if !translatedText.isEmpty {
                        resultCard
                    }
                    
                    // Error Display
                    if let error = translationError {
                        errorCard(error)
                    }
                }
                .padding()
            }
            .navigationTitle("Translate")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarButton
                }
            }
            .sheet(isPresented: $showingAPIKeySheet) {
                APIKeySettingsSheet(cloudService: cloudService)
            }
            .sheet(isPresented: $showingProviderPicker) {
                ProviderPickerSheet(selectedProvider: $selectedProvider)
            }
            .sheet(isPresented: $showingModelDownloader) {
                CoreMLModelDownloaderSheet(downloader: coreMLDownloader)
            }
            .sheet(isPresented: $showingAppleLanguages) {
                if let service = appleService {
                    AppleLanguagesSheet(appleService: service)
                }
            }
            .task {
                await appleTranslationService?.checkAvailableLanguages()
            }
        }
    }
    
    @ViewBuilder
    private var toolbarButton: some View {
        switch translationMode {
        case .apple:
            Button {
                showingAppleLanguages = true
            } label: {
                Image(systemName: "globe.badge.chevron.backward")
            }
        case .customAI:
            Button {
                showingModelDownloader = true
            } label: {
                Image(systemName: "arrow.down.circle")
            }
        case .cloud:
            Button {
                showingAPIKeySheet = true
            } label: {
                Image(systemName: "key.fill")
            }
        }
    }
    
    // MARK: - Mode Toggle
    
    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(TranslationMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        translationMode = mode
                        translationError = nil
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 16, weight: .semibold))
                        Text(mode.rawValue)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(translationMode == mode ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        translationMode == mode ? mode.color : Color.clear
                    )
                }
            }
        }
        .background(Color(.systemGray5))
        .cornerRadius(12)
    }
    
    // MARK: - Apple Translation Mode Content

    private var appleModeContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "apple.logo")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
                    .background(Color.blue.opacity(0.15))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Translation")
                        .font(.headline)
                    
                    if appleLanguageCount > 0 {
                        Text("\(appleLanguageCount) languages ready")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Checking availability...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()

                Button {
                    showingAppleLanguages = true
                } label: {
                    Text("Languages")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            // Benefits
            HStack(spacing: 12) {
                benefitBadge(icon: "lock.shield.fill", text: "Private", color: .green)
                benefitBadge(icon: "wifi.slash", text: "Offline", color: .blue)
                benefitBadge(icon: "bolt.fill", text: "Fast", color: .orange)
            }
        }
    }

    // MARK: - Custom AI Mode Content
    
    private var customAIModeContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Image(systemName: "cpu.fill")
                    .font(.title2)
                    .foregroundColor(.indigo)
                    .frame(width: 44, height: 44)
                    .background(Color.indigo.opacity(0.15))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("CoreML AI Models")
                        .font(.headline)
                    
                    if availableModelCount > 0 {
                        Text("\(availableModelCount) model(s) installed")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("No models installed")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                Button {
                    showingModelDownloader = true
                } label: {
                    Text(availableModelCount > 0 ? "Manage" : "Download")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            // Model info
            if availableModelCount == 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.indigo)
                        
                        Text("Custom AI Models")
                            .font(.caption.bold())
                            .foregroundColor(.indigo)
                    }
                    
                    Text("Download Opus-MT or Gemma models for advanced translation with context understanding. Perfect for OCR and custom phrase rules.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.indigo.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private func benefitBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2.bold())
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Cloud Mode Content
    
    private var cloudModeContent: some View {
        Button {
            showingProviderPicker = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: selectedProvider.icon)
                    .font(.title2)
                    .foregroundColor(selectedProvider.color)
                    .frame(width: 44, height: 44)
                    .background(selectedProvider.color.opacity(0.15))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedProvider.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(selectedProvider.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    // MARK: - Source Text Card
    
    private var sourceTextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Source Text")
                    .font(.headline)
                
                Spacer()
                
                // Language indicator
                Text("\(appState.sourceLanguage.id.uppercased()) → \(appState.targetLanguage.id.uppercased())")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.2))
                    .cornerRadius(8)
            }
            
            TextEditor(text: $sourceText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    Group {
                        if sourceText.isEmpty {
                            Text("Enter text to translate...")
                                .foregroundColor(.secondary)
                                .padding(.leading, 12)
                                .padding(.top, 16)
                        }
                    },
                    alignment: .topLeading
                )
            
            HStack {
                Text("\(sourceText.count) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Glossary toggle
                if glossaryEntryCount > 0 {
                    Toggle(isOn: $useGlossary) {
                        HStack(spacing: 4) {
                            Image(systemName: "text.book.closed")
                            Text("\(glossaryEntryCount)")
                        }
                        .font(.caption)
                    }
                    .toggleStyle(.button)
                    .tint(useGlossary ? .indigo : .gray)
                }
                
                Button("Paste") {
                    if let text = UIPasteboard.general.string {
                        sourceText = text
                    }
                }
                .font(.caption)
                
                Button("Clear") {
                    sourceText = ""
                    translatedText = ""
                    appliedGlossaryEntries = []
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Translate Button
    
    private var translateButton: some View {
        Button {
            Task {
                await translate()
            }
        } label: {
            HStack {
                if isTranslating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(isTranslating ? "Translating..." : "Translate")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(translateButtonColor)
            .cornerRadius(14)
        }
        .disabled(sourceText.isEmpty || isTranslating || !canTranslate)
    }
    
    private var translateButtonColor: Color {
        if sourceText.isEmpty || isTranslating || !canTranslate {
            return .gray
        }
        return translationMode.color
    }
    
    private var canTranslate: Bool {
        switch translationMode {
        case .apple:
            return true  // Apple handles availability
        case .customAI:
            return true  // Demo mode or actual models
        case .cloud:
            return !cloudService.getAPIKey(for: selectedProvider).isEmpty
        }
    }
    
    // MARK: - Result Card
    
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Translation")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = translatedText
                } label: {
                    Image(systemName: "doc.on.doc")
                }
            }
            
            Text(translatedText)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(translationMode.color.opacity(0.1))
                .cornerRadius(12)
                .textSelection(.enabled)
            
            // Show applied glossary entries
            if !appliedGlossaryEntries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "text.book.closed.fill")
                            .foregroundColor(.indigo)
                        Text("Glossary Applied")
                            .font(.caption.bold())
                            .foregroundColor(.indigo)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(appliedGlossaryEntries) { entry in
                                HStack(spacing: 4) {
                                    Text(entry.sourceText)
                                        .strikethrough()
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                    Text(entry.targetText)
                                        .bold()
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.indigo.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private func errorCard(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Dismiss") {
                translationError = nil
            }
            .font(.caption)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func translate() async {
        isTranslating = true
        translationError = nil
        appliedGlossaryEntries = []
        
        // Apply pre-translation glossary rules
        var textToTranslate = sourceText
        if useGlossary && glossaryEntryCount > 0 {
            let (processed, entries) = glossaryService.applyGlossary(
                to: sourceText,
                sourceLanguage: appState.sourceLanguage.id,
                targetLanguage: appState.targetLanguage.id,
                phase: .preTranslation
            )
            textToTranslate = processed
            appliedGlossaryEntries = entries
        }
        
        do {
            // Apple translation is handled by AppleTranslationView with .translationTask modifier
            // Skip performTranslation for Apple mode
            guard translationMode != .apple else {
                isTranslating = false
                return
            }

            var result: String

            switch translationMode {

            case .apple:
                // Apple translation is handled by AppleTranslationView, should not reach here
                throw AppleTranslationError.translationFailed("Apple translation should be handled by view")

            case .customAI:
                // Use custom CoreML models via TranslationService
                let translationResult = try await appState.translationService.translate(
                    text: textToTranslate,
                    from: appState.sourceLanguage,
                    to: appState.targetLanguage
                )
                result = translationResult.translatedText
                
            case .cloud:
                // Use cloud API
                result = try await cloudService.translate(
                    text: textToTranslate,
                    from: appState.sourceLanguage,
                    to: appState.targetLanguage,
                    using: selectedProvider
                )
            }
            
            // Apply post-translation glossary rules (if any)
            if useGlossary && glossaryEntryCount > 0 {
                let (postProcessed, postEntries) = glossaryService.applyGlossary(
                    to: result,
                    sourceLanguage: appState.sourceLanguage.id,
                    targetLanguage: appState.targetLanguage.id,
                    phase: .postTranslation
                )
                result = postProcessed
                appliedGlossaryEntries.append(contentsOf: postEntries)
            }
            
            // Increment usage count for applied entries (batch update for efficiency)
            glossaryService.batchIncrementUsage(for: appliedGlossaryEntries)
            
            translatedText = result
            
        } catch {
            translationError = error.localizedDescription
            translatedText = ""
        }
        
        isTranslating = false
    }
}

// MARK: - CoreML Model Downloader Sheet

struct CoreMLModelDownloaderSheet: View {
    let downloader: CoreMLModelDownloader
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Info section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cpu.fill")
                                .foregroundColor(.indigo)
                            Text("CoreML AI Models")
                                .font(.headline)
                        }
                        
                        Text("Download custom AI models for advanced translation. These models support **OCR text recognition** and **context-aware translation**.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // Download status
                if downloader.isDownloading, let model = downloader.currentDownload {
                    Section("Downloading") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.name)
                                .font(.subheadline.bold())
                            
                            ProgressView(value: downloader.downloadProgress)
                            
                            Text("\(Int(downloader.downloadProgress * 100))% complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Available models
                Section("Available Models") {
                    ForEach(downloader.availableModels) { model in
                        CoreMLModelRow(
                            model: model,
                            isDownloaded: downloader.isModelDownloaded(model.id),
                            isDownloading: downloader.currentDownload?.id == model.id
                        ) {
                            Task {
                                try? await downloader.downloadModel(model)
                            }
                        }
                    }
                }
                
                // Storage info
                Section {
                    HStack {
                        Image(systemName: "internaldrive")
                            .foregroundColor(.secondary)
                        Text("Storage used: \(ByteCountFormatter.string(fromByteCount: downloader.totalStorageUsed(), countStyle: .file))")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Models are stored locally and work offline")
                            .font(.caption)
                    }
                } header: {
                    Text("Info")
                }
                
                // Setup instructions
                Section("Model Hosting Setup") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("To enable downloads, you need to:")
                            .font(.caption.bold())
                        
                        Text("1. Convert models to CoreML using Python scripts in /MLModels")
                            .font(.caption)
                        Text("2. Host .mlpackage files on HuggingFace or GitHub")
                            .font(.caption)
                        Text("3. Update URLs in CoreMLModelDownloader.swift")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("AI Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct CoreMLModelRow: View {
    let model: DownloadableModel
    let isDownloaded: Bool
    let isDownloading: Bool
    let onDownload: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.body)
                
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(model.sizeFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isDownloaded {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if isDownloading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button {
                    onDownload()
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundColor(.indigo)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Apple Languages Sheet

@available(iOS 18.0, *)
struct AppleLanguagesSheet: View {
    let appleService: AppleTranslationService
    @Environment(\.dismiss) var dismiss
    
    let supportedLanguages = [
        ("en", "English", "🇺🇸"),
        ("es", "Spanish", "🇪🇸"),
        ("zh", "Chinese", "🇨🇳"),
        ("ja", "Japanese", "🇯🇵"),
        ("ko", "Korean", "🇰🇷"),
        ("fr", "French", "🇫🇷"),
        ("de", "German", "🇩🇪"),
        ("it", "Italian", "🇮🇹"),
        ("pt", "Portuguese", "🇵🇹"),
        ("ru", "Russian", "🇷🇺"),
        ("ar", "Arabic", "🇸🇦"),
    ]
    
    var body: some View {
        NavigationView {
            List {
                // Info section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.title2)
                            Text("Apple Translation")
                                .font(.headline)
                        }
                        
                        Text("Apple's built-in translation is **100% private** and works **offline**. Language packs are downloaded through iOS Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // How to download
                Section("Download Languages") {
                    VStack(alignment: .leading, spacing: 12) {
                        instructionStep(1, "Open **Settings** app")
                        instructionStep(2, "Go to **General**")
                        instructionStep(3, "Tap **Language & Region**")
                        instructionStep(4, "Tap **Translation Languages**")
                        instructionStep(5, "Download languages you need")
                    }
                    .padding(.vertical, 4)
                    
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                // Language status
                Section("Language Status") {
                    ForEach(supportedLanguages, id: \.0) { code, name, flag in
                        HStack {
                            Text(flag)
                                .font(.title2)
                            
                            Text(name)
                            
                            Spacer()
                            
                            if appleService.downloadedLanguages.contains(code) {
                                Label("Ready", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else {
                                Text("Not Downloaded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Benefits
                Section("Benefits") {
                    benefitRow("lock.shield.fill", .green, "100% Private", "All translation on-device")
                    benefitRow("wifi.slash", .blue, "Works Offline", "No internet needed")
                    benefitRow("bolt.fill", .orange, "Fast", "No network latency")
                    benefitRow("dollarsign.circle.fill", .purple, "Free", "No API costs")
                }
            }
            .navigationTitle("Apple Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await appleService.checkAvailableLanguages()
            }
        }
    }
    
    private func instructionStep(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .cornerRadius(10)
            
            Text(text)
                .font(.subheadline)
        }
    }
    
    private func benefitRow(_ icon: String, _ color: Color, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - API Key Settings Sheet

struct APIKeySettingsSheet: View {
    let cloudService: CloudTranslationService
    @Environment(\.dismiss) var dismiss
    
    @State private var googleKey: String = ""
    @State private var geminiKey: String = ""
    @State private var openAIKey: String = ""
    @State private var deepLKey: String = ""
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("API keys are stored locally on your device. Your keys are never sent anywhere except to the respective API services.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Google Cloud") {
                    SecureField("Google Translate API Key", text: $googleKey)
                        .textContentType(.password)
                    
                    Link("Get API Key →", destination: URL(string: "https://console.cloud.google.com/apis/credentials")!)
                        .font(.caption)
                }
                
                Section("Google Gemini") {
                    SecureField("Gemini API Key", text: $geminiKey)
                        .textContentType(.password)
                    
                    Link("Get API Key →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                        .font(.caption)
                }
                
                Section("OpenAI") {
                    SecureField("OpenAI API Key", text: $openAIKey)
                        .textContentType(.password)
                    
                    Link("Get API Key →", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .font(.caption)
                }
                
                Section("DeepL") {
                    SecureField("DeepL API Key", text: $deepLKey)
                        .textContentType(.password)
                    
                    Link("Get API Key →", destination: URL(string: "https://www.deepl.com/pro-api")!)
                        .font(.caption)
                }
            }
            .navigationTitle("API Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveKeys()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadKeys()
            }
        }
    }
    
    private func loadKeys() {
        googleKey = cloudService.googleAPIKey
        geminiKey = cloudService.geminiAPIKey
        openAIKey = cloudService.openAIAPIKey
        deepLKey = cloudService.deepLAPIKey
    }
    
    private func saveKeys() {
        cloudService.googleAPIKey = googleKey
        cloudService.geminiAPIKey = geminiKey
        cloudService.openAIAPIKey = openAIKey
        cloudService.deepLAPIKey = deepLKey
    }
}

// MARK: - Provider Picker Sheet

struct ProviderPickerSheet: View {
    @Binding var selectedProvider: CloudProvider
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(CloudProvider.allCases) { provider in
                    Button {
                        selectedProvider = provider
                        dismiss()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: provider.icon)
                                .font(.title2)
                                .foregroundColor(provider.color)
                                .frame(width: 44, height: 44)
                                .background(provider.color.opacity(0.15))
                                .cornerRadius(10)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(provider.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(provider.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if provider == selectedProvider {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.indigo)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Apple Translation View

/// Separate view for Apple Translation that uses .translationTask modifier
@available(iOS 18.0, *)
struct AppleTranslationView: View {
    @Environment(AppState.self) var appState
    let textToTranslate: String

    @State private var translatedResult: String?

    var body: some View {
        VStack {
            if let result = translatedResult {
                Text("Apple Translation: \(result)")
                    .font(.headline)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            } else {
                Text("Translating with Apple...")
                    .foregroundColor(.secondary)
            }
        }
        .translationTask(.init(
            source: Locale.Language(identifier: appState.sourceLanguage.id),
            target: Locale.Language(identifier: appState.targetLanguage.id)
        )) { session in
            do {
                let response = try await session.translate(textToTranslate)
                translatedResult = response.targetText
            } catch {
                translatedResult = "Translation failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Preview

#Preview {
    if #available(iOS 18.0, *) {
        TranslateView()
            .environment(AppState())
    } else {
        // Fallback on earlier versions
    }
}
