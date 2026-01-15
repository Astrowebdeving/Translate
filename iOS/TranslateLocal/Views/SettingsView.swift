//
//  SettingsView.swift
//  TranslateLocal
//
//  App settings and model management
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) var appState
    
    @State private var showingModelManager = false
    @State private var showingAbout = false
    
    var body: some View {
        @Bindable var state = appState
        
        NavigationView {
            List {
                // Language Settings
                Section {
                    NavigationLink {
                        LanguageSettingsView()
                    } label: {
                        HStack {
                            SettingsIcon(icon: "globe", color: .blue)
                            VStack(alignment: .leading) {
                                Text("Languages")
                                Text("\(appState.sourceLanguage.name) → \(appState.targetLanguage.name)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Toggle(isOn: $state.autoDetectLanguage) {
                        HStack {
                            SettingsIcon(icon: "wand.and.stars", color: .purple)
                            Text("Auto-detect Language")
                        }
                    }
                    .onChange(of: appState.autoDetectLanguage) { _, _ in
                        appState.saveSettings()
                    }
                } header: {
                    Text("Translation")
                }
                
                // Model Management
                Section {
                    NavigationLink {
                        ModelDownloadView()
                    } label: {
                        HStack {
                            SettingsIcon(icon: "icloud.and.arrow.down", color: .blue)
                            VStack(alignment: .leading) {
                                Text("Download Models")
                                Text("Get translation models from HuggingFace")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    NavigationLink {
                        ModelManagementView()
                    } label: {
                        HStack {
                            SettingsIcon(icon: "cpu", color: .green)
                            VStack(alignment: .leading) {
                                Text("Manage Models")
                                Text("\(appState.modelManager.loadedModels.count) loaded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Translation Models")
                } footer: {
                    Text("Download models to enable offline translation. Models use Helsinki-NLP Opus-MT architecture.")
                }
                
                // App Behavior
                Section {
                    Toggle(isOn: $state.continuousTranslation) {
                        HStack {
                            SettingsIcon(icon: "repeat", color: .orange)
                            Text("Continuous Translation")
                        }
                    }
                    .onChange(of: appState.continuousTranslation) { _, _ in
                        appState.saveSettings()
                    }
                    
                    Toggle(isOn: $state.hapticFeedback) {
                        HStack {
                            SettingsIcon(icon: "iphone.radiowaves.left.and.right", color: .pink)
                            Text("Haptic Feedback")
                        }
                    }
                    .onChange(of: appState.hapticFeedback) { _, _ in
                        appState.saveSettings()
                    }
                } header: {
                    Text("Behavior")
                }
                
                // About
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack {
                            SettingsIcon(icon: "info.circle", color: .indigo)
                            Text("About")
                        }
                    }
                    
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack {
                            SettingsIcon(icon: "hand.raised.fill", color: .red)
                            Text("Privacy")
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/yourusername/translatelocal")!) {
                        HStack {
                            SettingsIcon(icon: "chevron.left.forwardslash.chevron.right", color: .gray)
                            Text("Source Code")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
                
                // Version info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .navigationViewStyle(.stack)  // Fix for iPad navigation issues
    }
}

// MARK: - Settings Icon

struct SettingsIcon: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(color)
            .cornerRadius(6)
    }
}

// MARK: - Language Settings View

struct LanguageSettingsView: View {
    @Environment(AppState.self) var appState
    
    var body: some View {
        @Bindable var state = appState
        
        List {
            Section {
                ForEach(Language.allLanguages) { language in
                    Button {
                        state.sourceLanguage = language
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
            } header: {
                Text("Translate From")
            }
            
            Section {
                ForEach(Language.allLanguages) { language in
                    Button {
                        state.targetLanguage = language
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
            } header: {
                Text("Translate To")
            }
        }
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    appState.swapLanguages()
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
            }
        }
    }
}

// MARK: - Model Management View

struct ModelManagementView: View {
    @Environment(AppState.self) var appState
    
    var body: some View {
        List {
            Section {
                ForEach(TranslationModelType.allCases, id: \.self) { type in
                    ModelRow(type: type)
                }
            } header: {
                Text("Available Models")
            } footer: {
                Text("Models are stored locally on your device. Larger models provide better quality but use more storage and memory.")
            }
            
            Section {
                HStack {
                    Text("Memory Usage")
                    Spacer()
                    Text(formatBytes(appState.modelManager.getMemoryUsage()))
                        .foregroundColor(.secondary)
                }
                
                Button {
                    appState.modelManager.unloadAllModels()
                } label: {
                    HStack {
                        Image(systemName: "memorychip")
                        Text("Free Memory")
                    }
                }
                .disabled(appState.modelManager.loadedModels.isEmpty)
            } header: {
                Text("Memory")
            }
        }
        .navigationTitle("AI Models")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

struct ModelRow: View {
    let type: TranslationModelType
    @Environment(AppState.self) var appState
    @State private var isLoading = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(type.displayName)
                    .font(.body)
                
                if let info = appState.modelManager.availableModels[type] {
                    HStack {
                        Text(info.sizeFormatted)
                        if info.isBundled {
                            Text("• Bundled")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } else {
                    Text("Not available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Check if loaded in TranslationService (the one that actually matters)
            if appState.translationService.loadedModels.contains(type) {
                Button {
                    unloadModel()
                } label: {
                    Label("Unload", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else if appState.modelManager.isModelAvailable(type) {
                Button {
                    loadModel()
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Load")
                            .font(.caption.bold())
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Download")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func loadModel() {
        isLoading = true
        Task {
            do {
                // Use TranslationService.loadModel which loads encoder, decoder, AND tokenizer
                try await appState.translationService.loadModel(type)
                DebugLogger.model("Successfully loaded model \(type.rawValue) via Settings", level: .info)
            } catch {
                DebugLogger.model("Failed to load model via Settings: \(error)", level: .error)
            }
            isLoading = false
        }
    }
    
    private func unloadModel() {
        appState.translationService.unloadModel(type)
        DebugLogger.model("Unloaded model \(type.rawValue) via Settings", level: .info)
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon
                Image(systemName: "globe")
                    .font(.system(size: 80, weight: .light))
                    .foregroundColor(.indigo)
                    .padding(.top, 40)
                
                Text("TranslateLocal")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                    .padding(.horizontal, 40)
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "lock.shield.fill",
                        title: "100% Private",
                        description: "All translation happens on your device. Your data never leaves your iPhone."
                    )
                    
                    FeatureRow(
                        icon: "bolt.fill",
                        title: "Fast & Offline",
                        description: "Works without internet connection. No waiting for cloud responses."
                    )
                    
                    FeatureRow(
                        icon: "cpu.fill",
                        title: "AI Powered",
                        description: "Uses state-of-the-art compact language models optimized for mobile."
                    )
                    
                    FeatureRow(
                        icon: "dollarsign.circle.fill",
                        title: "No Subscriptions",
                        description: "One-time download, unlimited translations. No hidden costs."
                    )
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.indigo)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Privacy Policy View

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Last updated: January 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                PolicySection(
                    title: "Data Collection",
                    content: "TranslateLocal does not collect any personal data. All text processing happens entirely on your device."
                )
                
                PolicySection(
                    title: "No Cloud Processing",
                    content: "Your translations are never sent to external servers. The AI models run locally on your iPhone using Apple's Neural Engine."
                )
                
                PolicySection(
                    title: "No Analytics",
                    content: "We do not use any analytics or tracking services. Your usage patterns remain completely private."
                )
                
                PolicySection(
                    title: "Camera Access",
                    content: "The app requests camera access to enable real-time text recognition. Camera data is processed locally and never stored or transmitted."
                )
                
                PolicySection(
                    title: "Photo Library Access",
                    content: "When you choose to translate an image, the selected photo is processed locally. We do not access or store any other photos from your library."
                )
                
                PolicySection(
                    title: "Local Storage",
                    content: "Translation history is stored locally on your device using iOS's secure storage mechanisms. You can clear this history at any time from the History tab."
                )
                
                PolicySection(
                    title: "Contact",
                    content: "If you have any questions about this privacy policy, please contact us at privacy@translatelocal.app"
                )
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PolicySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppState())
}
