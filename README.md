# 🌐 TranslateLocal

> **Real-time, private text translation powered by on-device AI**

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

---

## Overview

TranslateLocal is an iOS application that provides **on-device text translation** using efficient AI models. All processing happens locally on your iPhone, ensuring:

- 🔒 **Complete Privacy** – No data leaves your device
- ⚡ **Fast Response** – No network latency
- 📴 **Offline Capable** – Works without internet
- 💰 **No Subscription** – One-time download, unlimited use

---

## Features

| Feature | Description |
|---------|-------------|
| 📷 **Camera Translation** | Point your camera at any text for real-time translation |
| 📺 **Screen Translation** | Translate text from ANY app with floating PiP window |
| 🖼️ **Image & Voice Translation** | Translate photos, screenshots, and voice input |
| 🔤 **Text Translation** | Type or paste text for instant translation |
| 🤖 **Multiple AI Engines** | Choose between Local AI (Opus-MT, Gemma 3n) or Apple Translation |
| ☁️ **Cloud APIs** | Optional support for Google, OpenAI, DeepL, and Gemini APIs |
| 📜 **Custom Glossary** | Define custom term translations |

---

## Technology Stack

| Technology | Purpose |
|------------|---------|
| **Vision Framework** | OCR - finds and reads text in images |
| **Core ML** | Runs Opus-MT translation models locally |
| **MLX Swift** | Runs Gemma 3n LLM for advanced translation |
| **Apple Translation** | iOS 18+ built-in translation (optional) |
| **SwiftUI** | Modern UI framework |
| **AVFoundation** | Camera and PiP support |

---

## Supported Models

| Model | Type | Size | Use Case |
|-------|------|------|----------|
| **Opus-MT** | CoreML | ~50-300MB each | Fast, language-pair specific translation |
| **Gemma 3n E2B** | MLX (4-bit) | ~1.5GB | Advanced multilingual translation, context-aware |
| **Apple Translation** | System | N/A | iOS 18+ built-in, requires language pack download |

---

## Requirements

- **iOS 17.0+** (iOS 18+ recommended for Apple Translation)
- **iPhone 13+** or **iPad with M1+** (for on-device AI)
- **8GB+ RAM** recommended for Gemma 3n Smart PiP features

---

## Getting Started

### 1. Clone & Open

```bash
git clone <repo-url>
cd TranslateLocal
open TranslateLocal.xcodeproj
```

### 2. Configure Signing

1. Open project settings in Xcode
2. Select your Development Team for all targets
3. Enable App Groups capability

### 3. Build & Run

1. Select your target device
2. Build and run (⌘ + R)
3. Download translation models from Settings tab

---

## Project Structure

```
TranslateLocal/
├── iOS/
│   ├── TranslateLocal/          # Main app
│   │   ├── Views/               # SwiftUI views
│   │   ├── Services/            # Core services (Translation, OCR, PiP, etc.)
│   │   └── App/                 # App entry point
│   ├── Shared/                  # Shared code with extensions
│   ├── BroadcastExtension/      # Screen capture for PiP
│   ├── ShareExtension/          # Share sheet integration
│   └── ActionExtension/         # Text selection action
├── MLModels/                    # Python model conversion scripts
├── Resources/                   # Assets, language configs
└── TranslateLocal.xcodeproj     # Xcode project
```

---

## Key Services

| Service | File | Purpose |
|---------|------|---------|
| `TranslationService` | `TranslationService.swift` | Main translation orchestrator |
| `GemmaService` | `GemmaService.swift` | Gemma 3n MLX inference |
| `MLXModelManager` | `MLXModelManager.swift` | Gemma model download/cache |
| `OCRService` | `OCRService.swift` | Text recognition (Vision) |
| `PiPService` | `PiPService.swift` | Picture-in-Picture management |
| `ScreenTranslationService` | `ScreenTranslationService.swift` | Screen translation coordinator |
| `AppleTranslationService` | `AppleTranslationService.swift` | iOS 18+ Translation framework |

---

## Memory Considerations

| Device | RAM | Gemma 3n Support | Notes |
|--------|-----|------------------|-------|
| iPhone 15 Pro / 16+ | 8GB | ✅ Full (Smart PiP) | Best experience |
| iPhone 14/15 | 6GB | ⚠️ Standard only | Smart PiP disabled |
| iPhone 13 | 4GB | ⚠️ Limited | Use Opus-MT |
| iPad M1+ | 8GB+ | ✅ Full | Excellent |

---

## License

MIT License – See [LICENSE](LICENSE) for details.

---

<p align="center">
  <b>Built with ❤️ for privacy-focused translation</b>
</p>
