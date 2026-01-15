//
//  ScreenTranslateView.swift
//  TranslateLocal
//
//  UI for controlling screen translation mode
//  Guides user through starting broadcast and displays status
//

import SwiftUI
import ReplayKit

struct ScreenTranslateView: View {
    @Environment(AppState.self) var appState
    
    @State private var screenService: ScreenTranslationService?
    @State private var showInstructions = false
    @State private var showLanguagePicker = false
    @State private var showDebugLogs = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var refreshTimer: Timer?
    @State private var refreshCount = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Simulator warning
                    #if targetEnvironment(simulator)
                    simulatorWarning
                    #endif
                    
                    // Header illustration (smaller when active)
                    if screenService?.isActive != true {
                        headerSection
                    }
                    
                    // Status card
                    statusCard
                    
                    // Controls
                    controlsSection
                    
                    // Statistics (when active)
                    if screenService?.isActive == true {
                        statisticsSection
                        debugSection
                    }
                    
                    // Instructions (collapsed when active)
                    if screenService?.isActive != true {
                        instructionsSection
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Screen Translation")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if screenService?.isActive == true {
                        Button {
                            showDebugLogs = true
                        } label: {
                            Image(systemName: "ladybug")
                                .foregroundColor(.orange)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showLanguagePicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(appState.sourceLanguage.id.uppercased())
                                .font(.caption.bold())
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                            Text(appState.targetLanguage.id.uppercased())
                                .font(.caption.bold())
                        }
                        .foregroundColor(.indigo)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)  // Fix for iPad navigation issues
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerSheet()
        }
        .sheet(isPresented: $showInstructions) {
            InstructionsSheet()
        }
        .sheet(isPresented: $showDebugLogs) {
            DebugLogSheet(screenService: screenService)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .onAppear {
            initializeService()
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
            // Don't stop service - PiP should continue
        }
    }
    
    // MARK: - Refresh Timer (for UI updates)
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            refreshCount += 1  // Trigger view refresh
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Subviews
    
    #if targetEnvironment(simulator)
    private var simulatorWarning: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading) {
                    Text("Simulator - Limited Functionality")
                        .font(.caption.bold())
                    Text("Screen Translation Overlay requires a real iPad device. Screen recording doesn't work on simulator.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // PiP demo button (for testing PiP window only)
            VStack(alignment: .leading, spacing: 4) {
                Text("PiP Demo Mode")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                Button {
                    testPiPOnSimulator()
                } label: {
                    HStack {
                        Image(systemName: "play.rectangle")
                        Text("Test PiP Window (Demo Only)")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.gray)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func testPiPOnSimulator() {
        Task {
            do {
                // Initialize service if needed
                if screenService == nil {
                    initializeService()
                }
                
                // Start the screen translation (which starts PiP)
                try await screenService?.start()
                
                // Wait a moment for PiP to fully initialize, then start demo mode
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                
                // Start demo mode to show sample translations
                screenService?.startDemoMode()
                
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    #endif
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.indigo.opacity(0.3), .purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                
                Image(systemName: "rectangle.inset.filled.and.person.filled")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text("Translate Any Screen")
                .font(.title2.bold())
            
            Text("Translate text from other apps in a floating window")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(statusText)
                    .font(.headline)
                
                Spacer()
                
                if screenService?.isActive == true {
                    Button {
                        showInstructions = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let lastPayload = screenService?.lastPayload, screenService?.isActive == true {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last detected:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(lastPayload.fullText.prefix(100) + (lastPayload.fullText.count > 100 ? "..." : ""))
                        .font(.callout)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let lastTranslation = screenService?.lastTranslation, 
               let mainBlock = lastTranslation.translations["main"],
               screenService?.isActive == true {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Translation:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(mainBlock.translatedText.prefix(100) + (mainBlock.translatedText.count > 100 ? "..." : ""))
                        .font(.callout)
                        .foregroundColor(.indigo)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            if screenService?.isActive != true {
                // Start button
                Button {
                    startScreenTranslation()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Screen Translation")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
            } else {
                // Overlay toggle (real device only)
                #if !targetEnvironment(simulator)
                overlayControlSection
                #endif
                
                // Stop button
                Button {
                    stopScreenTranslation()
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop Translation")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(14)
                }
                
                // Broadcast picker
                BroadcastPickerView()
                    .frame(height: 50)
                    .cornerRadius(12)
            }
        }
    }
    
    #if !targetEnvironment(simulator)
    private var overlayControlSection: some View {
        VStack(spacing: 12) {
            // Overlay mode toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Translation Overlay")
                        .font(.subheadline.bold())
                    Text(screenService?.isOverlayEnabled == true ? "Full-screen overlay active" : "Toggle button mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    screenService?.toggleOverlay()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: screenService?.isOverlayEnabled == true ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle")
                        Text(screenService?.isOverlayEnabled == true ? "Disable" : "Enable")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(screenService?.isOverlayEnabled == true ? Color.orange : Color.indigo)
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            // Overlay settings (when enabled)
            if screenService?.isOverlayEnabled == true {
                overlaySettingsSection
            }
        }
    }
    
    private var overlaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overlay Settings")
                .font(.caption.bold())
                .foregroundColor(.secondary)
            
            // Translation Provider Picker (iOS 18+ for Apple)
            VStack(alignment: .leading, spacing: 4) {
                Text("Translation Engine")
                    .font(.caption)
                
                Picker("Provider", selection: Binding(
                    get: { screenService?.translationProvider ?? .localAI },
                    set: { screenService?.translationProvider = $0 }
                )) {
                    ForEach(ScreenTranslationService.TranslationProvider.allCases, id: \.self) { provider in
                        Label(provider.rawValue, systemImage: provider.icon)
                            .tag(provider)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Opacity slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Background Opacity")
                        .font(.caption)
                    Spacer()
                    Text("\(Int((screenService?.overlayOpacity ?? 0.3) * 100))%")
                        .font(.caption.bold())
                }
                
                Slider(
                    value: Binding(
                        get: { Double(screenService?.overlayOpacity ?? 0.3) },
                        set: { screenService?.setOverlayOpacity(Float($0)) }
                    ),
                    in: 0.1...0.8
                )
                .tint(.indigo)
            }
            
            // Smart positioning toggle - RAM Gated
            if screenService?.isSmartOverlaySupported == true {
                Toggle(isOn: Binding(
                    get: { screenService?.useSmartPositioning ?? true },
                    set: { screenService?.useSmartPositioning = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart Positioning (Gemma)")
                            .font(.caption)
                        Text("Use AI to adjust translation positions")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .indigo))
            } else {
                // Show disabled state for low-RAM devices
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart Positioning (Gemma)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Requires 8GB+ RAM device")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                }
            }
            
            // Positioned translations count
            if let count = screenService?.positionedTranslations.count, count > 0 {
                HStack {
                    Image(systemName: "text.viewfinder")
                        .foregroundColor(.green)
                    Text("\(count) text blocks positioned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    #endif
    
    private var statisticsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                StatBox(
                    title: "OCR Frames",
                    value: "\(screenService?.processedFrameCount ?? 0)",
                    icon: "photo.stack"
                )
                
                StatBox(
                    title: "Translations",
                    value: "\(screenService?.translatedBlockCount ?? 0)",
                    icon: "text.bubble"
                )
                
                StatBox(
                    title: "PiP Frames",
                    value: "\(screenService?.pipFrameCount ?? 0)",
                    icon: "pip"
                )
            }
        }
    }
    
    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Debug Info")
                    .font(.caption.bold())
                Spacer()
                Text("Refresh: \(refreshCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Group {
                debugRow("PiP Status", value: screenService?.pipStatus ?? "N/A")
                debugRow("Overlay Mode", value: overlayModeText)
                debugRow("Broadcast", value: broadcastStatusText)
                debugRow("File Exists", value: (screenService?.fileExists ?? false) ? "Yes" : "No")
                debugRow("Last Check", value: screenService?.lastCheckTime.map { formatTime($0) } ?? "Never")
                debugRow("Positioned Blocks", value: "\(screenService?.positionedTranslations.count ?? 0)")
            }
            
            if let log = screenService?.debugLog, !log.isEmpty {
                Divider()
                Text("Recent Activity:")
                    .font(.caption2.bold())
                Text(log)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(10)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
    }
    
    private func debugRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption2.bold())
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it works")
                .font(.headline)
            
            InstructionRow(number: 1, text: "Tap \"Start Screen Translation\" to activate")
            InstructionRow(number: 2, text: "Use the broadcast picker to start recording")
            InstructionRow(number: 3, text: "Navigate to any app - translations appear in PiP")
            InstructionRow(number: 4, text: "Text is extracted and translated in real-time")
            
            Divider()
            
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                Text("Screen recording is required for this feature")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        guard let service = screenService else { return .gray }
        
        if !service.isActive {
            return .gray
        }
        
        switch service.broadcastState {
        case .inactive: return .orange
        case .starting: return .yellow
        case .active: return .green
        case .stopping: return .orange
        case .error: return .red
        }
    }
    
    private var statusText: String {
        guard let service = screenService else { return "Not initialized" }
        
        if !service.isActive {
            return "Inactive"
        }
        
        switch service.broadcastState {
        case .inactive: return "Waiting for broadcast..."
        case .starting: return "Starting..."
        case .active: return "Translating"
        case .stopping: return "Stopping..."
        case .error: return "Error"
        }
    }
    
    private var broadcastStatusText: String {
        guard let service = screenService else { return "-" }
        
        switch service.broadcastState {
        case .inactive: return "Off"
        case .starting: return "Starting"
        case .active: return "Live"
        case .stopping: return "Stopping"
        case .error: return "Error"
        }
    }
    
    private var overlayModeText: String {
        guard let service = screenService else { return "-" }
        
        if service.isOverlayEnabled {
            return "Full Overlay"
        } else {
            return "Toggle Button"
        }
    }
    
    // MARK: - Actions
    
    private func initializeService() {
        if screenService == nil {
            screenService = ScreenTranslationService(translationService: appState.translationService)
            screenService?.sourceLanguage = appState.sourceLanguage
            screenService?.targetLanguage = appState.targetLanguage
        }
    }
    
    private func startScreenTranslation() {
        guard let service = screenService else { return }
        
        service.sourceLanguage = appState.sourceLanguage
        service.targetLanguage = appState.targetLanguage
        
        Task {
            do {
                try await service.start()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func stopScreenTranslation() {
        #if targetEnvironment(simulator)
        screenService?.stopDemoMode()
        #endif
        screenService?.stop()
    }
}

// MARK: - Supporting Views

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.indigo)
            
            Text(value)
                .font(.title3.bold())
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.indigo)
                .clipShape(Circle())
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct InstructionsSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("""
                    Screen translation uses iOS Screen Recording to capture text from other apps.
                    
                    **How to start:**
                    1. Tap the broadcast picker button
                    2. Select "TranslateLocal Screen"
                    3. Tap "Start Broadcast"
                    
                    **While active:**
                    • Text on screen is extracted every 1 second
                    • Translations appear in the floating PiP window
                    • You can move the PiP window anywhere
                    
                    **Privacy:**
                    • All processing happens on your device
                    • No screen content is sent anywhere
                    • Recording stops when you tap "Stop"
                    
                    **Tips:**
                    • Works best with clear, readable text
                    • Large text translates more accurately
                    • Some apps may block screen recording
                    """)
                    .font(.body)
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Broadcast Picker

struct BroadcastPickerView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 50))
        containerView.backgroundColor = .systemIndigo
        containerView.layer.cornerRadius = 12
        
        let picker = RPSystemBroadcastPickerView(frame: containerView.bounds)
        picker.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Set the bundle identifier of the broadcast extension
        picker.preferredExtension = "oceania1984.InIndiana.AWT.TranslateLocal.BroadcastExtension"
        
        // Customize appearance
        picker.showsMicrophoneButton = false
        
        // Style the internal button
        for subview in picker.subviews {
            if let button = subview as? UIButton {
                button.setImage(nil, for: .normal)
                button.setTitle("📺 Start Screen Recording", for: .normal)
                button.setTitleColor(.white, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
                button.backgroundColor = .clear
            }
        }
        
        containerView.addSubview(picker)
        
        // Add a label overlay
        let label = UILabel()
        label.text = "Tap to Start Recording"
        label.textColor = .white.withAlphaComponent(0.9)
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.frame = containerView.bounds
        label.isUserInteractionEnabled = false
        containerView.addSubview(label)
        containerView.sendSubviewToBack(label)
        
        DebugLogger.broadcast("Broadcast picker created", level: .info)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update if needed
    }
}

// MARK: - Debug Log Sheet

struct DebugLogSheet: View {
    let screenService: ScreenTranslationService?
    @Environment(\.dismiss) var dismiss
    @State private var logs: [DebugLogger.LogEntry] = []
    
    var body: some View {
        NavigationView {
            List {
                Section("Screen Translation Logs") {
                    ForEach(DebugLogger.getRecentLogs(count: 50).reversed()) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.level.rawValue)
                                Text(entry.formattedTimestamp)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("[\(entry.category.rawValue)]")
                                    .font(.caption2)
                                    .foregroundColor(.indigo)
                            }
                            Text(entry.message)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                if let service = screenService {
                    Section("Service Debug Log") {
                        Text(service.debugLog)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("App Group Info") {
                    if let url = AppGroupConstants.sharedContainerURL {
                        Text("Container: \(url.lastPathComponent)")
                            .font(.caption)
                    } else {
                        Text("Container: NOT AVAILABLE")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Text("Payload file exists: \(AppGroupConstants.fileExists(AppGroupConstants.screenPayloadFileName) ? "Yes" : "No")")
                        .font(.caption)
                }
            }
            .navigationTitle("Debug Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        DebugLogger.clearLogs()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ScreenTranslateView()
        .environment(AppState())
}
