//
//  ContentView.swift
//  TranslateLocal
//
//  Main tab-based navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .camera
    
    enum Tab: String, CaseIterable {
        case camera = "Camera"
        case image = "Image"
        case history = "History"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .camera: return "camera.viewfinder"
            case .image: return "photo.on.rectangle"
            case .history: return "clock.arrow.circlepath"
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
            
            ImageTranslateView()
                .tabItem {
                    Label(Tab.image.rawValue, systemImage: Tab.image.icon)
                }
                .tag(Tab.image)
            
            HistoryView()
                .tabItem {
                    Label(Tab.history.rawValue, systemImage: Tab.history.icon)
                }
                .tag(Tab.history)
            
            SettingsView()
                .tabItem {
                    Label(Tab.settings.rawValue, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .tint(.indigo)
        .onAppear {
            setupAppearance()
        }
        .sheet(isPresented: .constant(!appState.hasCompletedOnboarding)) {
            OnboardingView()
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
    @EnvironmentObject var appState: AppState
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
                    description: "All translation happens on your device. Your text never leaves your iPhone.",
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
        .interactiveDismissDisabled()
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

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}
