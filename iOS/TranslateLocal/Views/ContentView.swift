//
//  ContentView.swift
//  TranslateLocal
//
//  Main tab-based navigation
//

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState
    @State private var selectedTab: Tab = .camera
    @State private var showOnboarding = false
    
    enum Tab: String, CaseIterable {
        case camera = "Camera"
        case screen = "Screen"
        case image = "Image"
        case translate = "Translate"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .camera: return "camera.viewfinder"
            case .screen: return "rectangle.inset.filled.and.person.filled"
            case .image: return "photo.on.rectangle"
            case .translate: return "textformat"
            case .settings: return "gearshape"
            }
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CameraTranslateView()
                .tabItem {
                    Label(Tab.camera.rawValue, systemImage: Tab.camera.icon)
                }
                .tag(Tab.camera)
            
            ScreenTranslateView()
                .tabItem {
                    Label(Tab.screen.rawValue, systemImage: Tab.screen.icon)
                }
                .tag(Tab.screen)
            
            ImageTranslateView()
                .tabItem {
                    Label(Tab.image.rawValue, systemImage: Tab.image.icon)
                }
                .tag(Tab.image)
            
            Group {
                if #available(iOS 18.0, *) {
                    TranslateView()
                } else {
                    // Fallback for iOS 17
                    TranslateViewFallback()
                }
            }
            .tabItem {
                Label(Tab.translate.rawValue, systemImage: Tab.translate.icon)
            }
            .tag(Tab.translate)
            
            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(.indigo)
        .onAppear {
            setupAppearance()
            // Check if onboarding needed
            showOnboarding = !appState.hasCompletedOnboarding
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .interactiveDismissDisabled()
        }
    }
    
    private func setupAppearance() {
        // Customize tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @Environment(AppState.self) var appState
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                OnboardingPage(
                    icon: "globe",
                    title: "Translate Anywhere",
                    description: "Point your camera at any text to instantly translate it. Works completely offline.",
                    color: .indigo
                )
                .tag(0)
                
                OnboardingPage(
                    icon: "lock.shield",
                    title: "100% Private",
                    description: "All translation happens on your device. Without your permission in the cloud services tab, your text never leaves your iPhone.",
                    color: .green
                )
                .tag(1)
                
                OnboardingPage(
                    icon: "bolt.fill",
                    title: "Fast & Efficient",
                    description: "Powered by compact AI models optimized for mobile. No subscriptions required.",
                    color: .orange
                )
                .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            Button {
                if currentPage < 2 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    appState.completeOnboarding()
                    isPresented = false
                }
            } label: {
                Text(currentPage < 2 ? "Continue" : "Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

struct OnboardingPage: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(color)
                .padding(.bottom, 20)
            
            Text(title)
                .font(.title)
                .fontWeight(.bold)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Translate View Fallback (iOS 17)

/// Fallback translation view for iOS versions below 18
struct TranslateViewFallback: View {
    @Environment(AppState.self) var appState
    @State private var inputText = ""
    @State private var outputText = ""
    @State private var isTranslating = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("From: \(appState.sourceLanguage.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $inputText)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Translate button
                Button {
                    Task { await translate() }
                } label: {
                    HStack {
                        if isTranslating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("Translate")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.indigo)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(inputText.isEmpty || isTranslating)
                .padding(.horizontal)
                
                // Output
                VStack(alignment: .leading, spacing: 8) {
                    Text("To: \(appState.targetLanguage.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(outputText.isEmpty ? "Translation will appear here..." : outputText)
                            .foregroundColor(outputText.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(height: 120)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Note about iOS 18
                Text("💡 Update to iOS 18+ for Apple Translation and more features")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .navigationTitle("Translate")
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
    
    private func translate() async {
        isTranslating = true
        defer { isTranslating = false }
        
        do {
            let result = try await appState.translationService.translate(
                text: inputText,
                from: appState.sourceLanguage,
                to: appState.targetLanguage
            )
            outputText = result.translatedText
        } catch {
            outputText = "Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(AppState())
}
