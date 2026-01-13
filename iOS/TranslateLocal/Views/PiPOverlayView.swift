//
//  PiPOverlayView.swift
//  TranslateLocal
//
//  SwiftUI view rendered inside the Picture-in-Picture window
//  Supports two modes: toggle button and full overlay with positioned translations
//

import SwiftUI

// MARK: - Overlay Mode

/// Display mode for the PiP overlay
enum OverlayMode: Equatable {
    /// Small toggle button mode (80x80)
    case toggle
    
    /// Full overlay mode with positioned translations
    case fullOverlay
    
    var size: CGSize {
        switch self {
        case .toggle:
            return CGSize(width: 80, height: 80)
        case .fullOverlay:
            return CGSize(width: 480, height: 640)  // Portrait aspect ratio for overlay
        }
    }
}

/// Status of the PiP translation display
enum PiPDisplayStatus {
    case waiting
    case translating
    case error
    case paused
    case inactive
}

// MARK: - Main Overlay View

/// The view displayed inside the PiP window
/// Supports both toggle button mode and full overlay mode
struct PiPOverlayView: View {
    // MARK: - Properties
    
    var mode: OverlayMode = .toggle
    var status: PiPDisplayStatus = .waiting
    var isTranslationEnabled: Bool = false
    var positionedTranslations: [PositionedTranslation] = []
    var overlayOpacity: Double = 0.3
    
    // Legacy support
    var translatedText: String = ""
    var originalText: String? = nil
    
    var body: some View {
        Group {
            switch mode {
            case .toggle:
                ToggleModeView(
                    status: status,
                    isEnabled: isTranslationEnabled
                )
                .frame(width: 80, height: 80)
                
            case .fullOverlay:
                FullOverlayView(
                    status: status,
                    translations: positionedTranslations,
                    opacity: overlayOpacity
                )
                .frame(width: 480, height: 640)
            }
        }
    }
}

// MARK: - Toggle Mode View

/// Small circular toggle button view
struct ToggleModeView: View {
    let status: PiPDisplayStatus
    let isEnabled: Bool
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: backgroundColors,
                        center: .center,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
            
            // Icon
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(statusLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Status ring
            Circle()
                .stroke(statusColor, lineWidth: 3)
                .frame(width: 74, height: 74)
            
            // Pulsing animation when active
            if status == .translating {
                Circle()
                    .stroke(Color.green.opacity(0.5), lineWidth: 2)
                    .frame(width: 78, height: 78)
                    .scaleEffect(1.1)
                    .opacity(0.7)
            }
        }
    }
    
    private var backgroundColors: [Color] {
        if isEnabled {
            return [Color(hex: "0f3460"), Color(hex: "1a1a2e")]
        } else {
            return [Color(hex: "2d2d44"), Color(hex: "1a1a2e")]
        }
    }
    
    private var iconName: String {
        switch status {
        case .waiting: return "clock"
        case .translating: return "globe"
        case .error: return "exclamationmark.triangle"
        case .paused: return "pause.circle"
        case .inactive: return "power"
        }
    }
    
    private var statusLabel: String {
        switch status {
        case .waiting: return "Ready"
        case .translating: return "Live"
        case .error: return "Error"
        case .paused: return "Paused"
        case .inactive: return "Tap"
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .waiting: return .yellow
        case .translating: return .green
        case .error: return .red
        case .paused: return .orange
        case .inactive: return .gray
        }
    }
}

// MARK: - Full Overlay View

/// Full-screen semi-transparent overlay with positioned translations
struct FullOverlayView: View {
    let status: PiPDisplayStatus
    let translations: [PositionedTranslation]
    let opacity: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(opacity)
                
                // Positioned translation blocks
                ForEach(translations) { translation in
                    TranslationBlockView(
                        translation: translation,
                        containerSize: geometry.size
                    )
                }
                
                // Header bar
                VStack {
                    headerBar
                    Spacer()
                    footerBar
                }
            }
        }
    }
    
    private var headerBar: some View {
        HStack {
            // App indicator
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .semibold))
                Text("TranslateLocal")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.5))
            .cornerRadius(16)
            
            Spacer()
            
            // Status badge
            HStack(spacing: 4) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.5))
            .cornerRadius(12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    private var footerBar: some View {
        HStack {
            Text("\(translations.count) blocks translated")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text(timeString)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var statusColor: Color {
        switch status {
        case .waiting: return .yellow
        case .translating: return .green
        case .error: return .red
        case .paused: return .orange
        case .inactive: return .gray
        }
    }
    
    private var statusText: String {
        switch status {
        case .waiting: return "Waiting"
        case .translating: return "Live"
        case .error: return "Error"
        case .paused: return "Paused"
        case .inactive: return "Off"
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - Translation Block View

/// Individual positioned translation block
struct TranslationBlockView: View {
    let translation: PositionedTranslation
    let containerSize: CGSize
    
    var body: some View {
        let rect = translation.pixelRect(for: containerSize)
        
        Text(translation.translatedText)
            .font(.system(size: translation.fontSize(baseSize: 14), weight: fontWeight))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
            .lineLimit(maxLines)
            .minimumScaleFactor(0.7)
            .frame(width: max(rect.width, 50), height: max(rect.height, 20), alignment: textAlignment)
            .position(x: rect.midX, y: rect.midY)
    }
    
    private var fontWeight: Font.Weight {
        switch translation.blockType {
        case .header: return .bold
        case .button: return .semibold
        case .navigation: return .medium
        default: return .regular
        }
    }
    
    private var maxLines: Int {
        switch translation.blockType {
        case .header: return 2
        case .body: return 6
        case .button, .label: return 1
        case .navigation: return 1
        case .unknown: return 3
        }
    }
    
    private var textAlignment: Alignment {
        switch translation.blockType {
        case .header: return .center
        case .button: return .center
        case .navigation: return .center
        default: return .leading
        }
    }
}

// MARK: - Legacy Simple View (for backwards compatibility)

/// Simple overlay view for basic translation display
struct SimplePiPOverlayView: View {
    var translatedText: String = ""
    var originalText: String? = nil
    var status: PiPDisplayStatus = .waiting
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 8) {
                // Header
                headerView
                
                Spacer()
                
                // Content
                contentView
                
                Spacer()
                
                // Footer status
                footerView
            }
            .padding(16)
        }
        .frame(width: 480, height: 270)
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "globe")
                .font(.system(size: 14, weight: .semibold))
            
            Text("TranslateLocal")
                .font(.system(size: 14, weight: .semibold))
            
            Spacer()
            
            statusBadge
        }
        .foregroundColor(.white.opacity(0.9))
    }
    
    private var contentView: some View {
        VStack(spacing: 12) {
            switch status {
            case .waiting, .inactive:
                waitingContent
            case .translating:
                translationContent
            case .error:
                errorContent
            case .paused:
                pausedContent
            }
        }
    }
    
    private var waitingContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "record.circle")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Waiting for Screen Recording...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Text("Start screen recording to begin translation")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    private var translationContent: some View {
        VStack(spacing: 8) {
            if let original = originalText, !original.isEmpty {
                Text(original)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            if !translatedText.isEmpty {
                Text(translatedText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(4)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            } else {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var errorContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.yellow)
            
            Text(translatedText.isEmpty ? "Translation Error" : translatedText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
    }
    
    private var pausedContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Translation Paused")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
        }
    }
    
    private var footerView: some View {
        HStack {
            Text(footerText)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
            
            Spacer()
            
            if status == .translating {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }
    
    private var backgroundColors: [Color] {
        switch status {
        case .waiting, .inactive:
            return [Color(hex: "1a1a2e"), Color(hex: "16213e")]
        case .translating:
            return [Color(hex: "0f3460"), Color(hex: "16213e")]
        case .error:
            return [Color(hex: "4a1942"), Color(hex: "1a1a2e")]
        case .paused:
            return [Color(hex: "2d2d44"), Color(hex: "1a1a2e")]
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .waiting, .inactive: return .yellow
        case .translating: return .green
        case .error: return .red
        case .paused: return .orange
        }
    }
    
    private var statusText: String {
        switch status {
        case .waiting, .inactive: return "Waiting"
        case .translating: return "Active"
        case .error: return "Error"
        case .paused: return "Paused"
        }
    }
    
    private var footerText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Previews

#Preview("Toggle Mode") {
    VStack(spacing: 20) {
        PiPOverlayView(mode: .toggle, status: .inactive, isTranslationEnabled: false)
        PiPOverlayView(mode: .toggle, status: .waiting, isTranslationEnabled: true)
        PiPOverlayView(mode: .toggle, status: .translating, isTranslationEnabled: true)
        PiPOverlayView(mode: .toggle, status: .error, isTranslationEnabled: true)
    }
    .padding()
    .background(Color.gray)
}

#Preview("Full Overlay") {
    let sampleTranslations = [
        PositionedTranslation(
            originalText: "Settings",
            translatedText: "Settings",
            blockType: .header,
            originalRect: CGRect(x: 0.1, y: 0.85, width: 0.8, height: 0.05),
            fontScale: 1.5
        ),
        PositionedTranslation(
            originalText: "Account",
            translatedText: "Account",
            blockType: .label,
            originalRect: CGRect(x: 0.1, y: 0.7, width: 0.3, height: 0.03),
            fontScale: 1.0
        ),
        PositionedTranslation(
            originalText: "Privacy & Security",
            translatedText: "Privacy",
            blockType: .button,
            originalRect: CGRect(x: 0.1, y: 0.6, width: 0.5, height: 0.03),
            fontScale: 1.0
        )
    ]
    
    PiPOverlayView(
        mode: .fullOverlay,
        status: .translating,
        isTranslationEnabled: true,
        positionedTranslations: sampleTranslations,
        overlayOpacity: 0.3
    )
    .scaleEffect(0.5)
}
