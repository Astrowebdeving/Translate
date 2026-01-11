//
//  PiPOverlayView.swift
//  TranslateLocal
//
//  SwiftUI view rendered inside the Picture-in-Picture window
//  Shows translated text with a clean, readable design
//

import SwiftUI

/// Status of the PiP translation display
enum PiPDisplayStatus {
    case waiting
    case translating
    case error
    case paused
}

/// The view displayed inside the PiP window
struct PiPOverlayView: View {
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
    
    // MARK: - Subviews
    
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
            case .waiting:
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
            
            Text("Open Control Center → Long-press Record → Select TranslateLocal")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var translationContent: some View {
        VStack(spacing: 8) {
            // Original text (if shown)
            if let original = originalText, !original.isEmpty {
                Text(original)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            // Translated text
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
    
    // MARK: - Computed Properties
    
    private var backgroundColors: [Color] {
        switch status {
        case .waiting:
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
        case .waiting: return .yellow
        case .translating: return .green
        case .error: return .red
        case .paused: return .orange
        }
    }
    
    private var statusText: String {
        switch status {
        case .waiting: return "Waiting"
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

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        PiPOverlayView(status: .waiting)
            .scaleEffect(0.6)
        
        PiPOverlayView(
            translatedText: "こんにちは、世界！",
            originalText: "Hello, World!",
            status: .translating
        )
        .scaleEffect(0.6)
        
        PiPOverlayView(
            translatedText: "Failed to connect",
            status: .error
        )
        .scaleEffect(0.6)
    }
}
