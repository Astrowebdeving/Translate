# 🌐 TranslateLocal - On-Device iOS Translation App

> **Real-time, private text translation powered by local AI models**

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://developer.apple.com)
[![Python](https://img.shields.io/badge/Python-3.10+-green.svg)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)

---

## 🚀 Quick Start

**New to this project? Start here:**

1. 📖 **Read this README** - Understand what the app does and its feasibility
2. 📘 **[GETTING_STARTED.md](GETTING_STARTED.md)** - Step-by-step Xcode setup instructions
3. 🏗️ **[ARCHITECTURE.md](ARCHITECTURE.md)** - Deep dive into how everything works

---

## 📋 Table of Contents

- [Overview](#-overview)
- [How It Works](#-how-it-works-simple-explanation)
- [Feasibility Analysis](#-feasibility-analysis)
- [Architecture](#-architecture)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [Model Conversion](#-model-conversion)
- [Development Roadmap](#-development-roadmap)

---

## 🎯 Overview

TranslateLocal is an iOS application that provides **on-device text translation** using small, efficient multilingual models like **Gemma-3n-E2B**. All processing happens locally on your iPhone, ensuring:

- 🔒 **Complete Privacy** - No data leaves your device
- ⚡ **Fast Response** - No network latency
- 📴 **Offline Capable** - Works without internet
- 💰 **No Subscription** - One-time download, unlimited use

### Key Features

| Feature | Description |
|---------|-------------|
| 📷 **Camera Translation** | Point your camera at any text for real-time translation |
| 🖼️ **Screenshot Translation** | Share screenshots from any app for instant translation |
| 🔤 **Text Selection** | Translate selected text in Safari and other apps via Action Extension |
| 🌐 **In-App Browser** | Browse with translation overlay |
| 📜 **History** | Track your translation history locally |

---

## 🧠 How It Works (Simple Explanation)

### The Big Picture

Think of TranslateLocal like having a translator living inside your iPhone:

```
📷 You See Text → 🔍 App Finds Text → 🤖 AI Translates → 📱 You See Translation
   (camera/photo)     (OCR magic)       (local model)      (overlay on screen)
```

### Step-by-Step Breakdown

#### 1️⃣ **Capturing Text** (OCR - Optical Character Recognition)

When you point your camera at text or select an image:

```
Image with text "Hello"
         │
         ▼
   ┌─────────────────────────────────────┐
   │     Apple Vision Framework          │
   │  (Built into every iPhone)          │
   │                                     │
   │  • Finds regions that look like     │
   │    text in the image                │
   │  • Reads the characters             │
   │  • Returns: "Hello" + position      │
   │    (where it is in the image)       │
   └─────────────────────────────────────┘
         │
         ▼
   Text: "Hello"
   Position: top-left corner
```

**Why this is cool**: Apple's Vision framework is:
- Already on your iPhone (no download needed)
- Extremely fast and accurate
- Supports 12+ languages
- 100% local/private

#### 2️⃣ **Translating Text** (AI/ML - Machine Learning)

Once we have the text, we need to translate it:

```
Text: "Hello"
         │
         ▼
   ┌─────────────────────────────────────┐
   │     AI Translation Model            │
   │  (Gemma-3n or Opus-MT)              │
   │                                     │
   │  • Takes text in one language       │
   │  • Neural network processes it      │
   │  • Outputs text in target language  │
   │                                     │
   │  "Hello" → [neural magic] → "こんにちは" │
   └─────────────────────────────────────┘
         │
         ▼
   Translation: "こんにちは"
```

**What's a "model"?**: 
- A model is like a very smart dictionary
- But instead of word-for-word lookup, it understands context
- "I'm cool" → Japanese (casual): 俺はクールだ
- "It's cool" → Japanese: 涼しいです
- Same word "cool", different translations based on meaning!

#### 3️⃣ **Displaying Results**

Finally, we show the translation:

```
   ┌─────────────────────────────────────┐
   │                                     │
   │   Original image with "Hello"       │
   │                                     │
   │      [Hello]                        │
   │       ↓                             │
   │   ┌─────────────┐                   │
   │   │ こんにちは   │  ← Floating      │
   │   └─────────────┘    translation    │
   │                                     │
   └─────────────────────────────────────┘
```

### Why "Local" Matters

| Cloud Translation | Local Translation |
|-------------------|-------------------|
| 📤 Send text to Google/Apple servers | 📱 Everything stays on your phone |
| 🌐 Requires internet | 📴 Works offline |
| 🔍 Company can read your text | 🔒 100% private |
| 💸 Often subscription-based | 💰 Free forever |
| ⏱️ Network delay | ⚡ Instant response |

### The Technologies Used

| Technology | What It Does | Who Made It |
|------------|--------------|-------------|
| **Vision Framework** | Finds and reads text in images | Apple (built into iOS) |
| **Core ML** | Runs AI models on iPhone | Apple (built into iOS) |
| **Gemma-3n** | Multilingual translation model | Google (we convert it) |
| **Opus-MT** | Language-pair translation models | University of Helsinki |
| **SwiftUI** | Modern iOS user interface | Apple |
| **AVFoundation** | Camera access and control | Apple |

---

## 🔬 Feasibility Analysis

### ✅ What's Fully Feasible

| Component | Technology | Status |
|-----------|------------|--------|
| **OCR/Text Recognition** | Apple Vision Framework | ✅ Excellent, built-in |
| **On-Device ML** | Core ML + Neural Engine | ✅ Optimized for iPhone |
| **Camera-Based Translation** | AVFoundation + Vision | ✅ Well-documented |
| **Share Extension** | iOS Extension APIs | ✅ Standard approach |
| **Action Extension** | iOS Extension APIs | ✅ Standard approach |
| **Local LLM** | Gemma-3n-E2B via Core ML | ✅ Feasible with conversion |

### ⚠️ iOS Limitations (Important!)

**Screen Capture Restrictions:**
- iOS sandboxing **prevents apps from capturing other apps' screens** for privacy
- The "translate on scroll" feature for arbitrary apps is **not possible** via traditional screen capture
- **Alternative approaches** (all implemented in this project):
  1. **Camera Mode**: Point iPhone camera at any screen (including another device)
  2. **Share Extension**: Share screenshots/text from any app
  3. **Action Extension**: Translate selected text in compatible apps
  4. **In-App Browser**: Full translation support while browsing

### 📊 Model Considerations

| Model | Size | Languages | Pros | Cons |
|-------|------|-----------|------|------|
| **Gemma-3n-E2B** | ~800MB | 35+ | Latest, efficient | Newer, less documented |
| **NLLB-200** | ~600MB-2GB | 200 | Best coverage | Larger variants needed for quality |
| **mBART-50** | ~2.4GB | 50 | Well-tested | Larger size |
| **Opus-MT** | ~50-300MB each | Pairs | Small per-pair | Need multiple for each language pair |

**Recommendation**: Start with **Gemma-3n-E2B** for general use, with **Opus-MT** pairs as fallbacks for specific language combinations.

### 💾 Memory & Performance

| iPhone Model | RAM | Feasibility | Notes |
|--------------|-----|-------------|-------|
| iPhone 15 Pro | 8GB | ✅ Excellent | Can run larger models |
| iPhone 14/15 | 6GB | ✅ Good | Gemma-3n runs well |
| iPhone 13 | 4GB | ⚠️ Limited | May need smaller models |
| iPhone 12 | 4GB | ⚠️ Limited | Consider Opus-MT pairs |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         TranslateLocal                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Camera     │  │    Share     │  │       Action         │  │
│  │    View      │  │  Extension   │  │      Extension       │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                 │                      │              │
│         └─────────────────┼──────────────────────┘              │
│                           │                                     │
│                           ▼                                     │
│              ┌────────────────────────┐                         │
│              │   OCR Service          │                         │
│              │   (Vision Framework)   │                         │
│              └───────────┬────────────┘                         │
│                          │                                      │
│                          ▼                                      │
│              ┌────────────────────────┐                         │
│              │  Translation Service   │                         │
│              │   (Core ML + Gemma)    │                         │
│              └───────────┬────────────┘                         │
│                          │                                      │
│                          ▼                                      │
│              ┌────────────────────────┐                         │
│              │   Result Display       │                         │
│              │   (SwiftUI Overlay)    │                         │
│              └────────────────────────┘                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
TranslateLocal/
├── 📁 iOS/                           # Main iOS Application
│   ├── TranslateLocal/
│   │   ├── 📁 App/
│   │   │   ├── TranslateLocalApp.swift
│   │   │   └── AppDelegate.swift
│   │   ├── 📁 Views/
│   │   │   ├── ContentView.swift
│   │   │   ├── CameraTranslateView.swift
│   │   │   ├── ImageTranslateView.swift
│   │   │   ├── HistoryView.swift
│   │   │   └── SettingsView.swift
│   │   ├── 📁 Services/
│   │   │   ├── OCRService.swift
│   │   │   ├── TranslationService.swift
│   │   │   ├── ModelManager.swift
│   │   │   └── LanguageDetector.swift
│   │   ├── 📁 Models/
│   │   │   ├── TranslationResult.swift
│   │   │   ├── Language.swift
│   │   │   └── TranslationHistory.swift
│   │   ├── 📁 ViewModels/
│   │   │   ├── CameraViewModel.swift
│   │   │   └── TranslationViewModel.swift
│   │   └── 📁 Resources/
│   │       ├── Assets.xcassets
│   │       └── Info.plist
│   ├── 📁 ShareExtension/            # Share screenshots/text
│   │   ├── ShareViewController.swift
│   │   └── Info.plist
│   └── 📁 ActionExtension/           # Text selection action
│       ├── ActionViewController.swift
│       └── Info.plist
│
├── 📁 MLModels/                      # Python model preparation
│   ├── convert_gemma_to_coreml.py
│   ├── convert_opus_to_coreml.py
│   ├── optimize_model.py
│   ├── test_conversion.py
│   └── requirements.txt
│
├── 📁 Resources/
│   ├── 📁 Models/                    # Converted Core ML models
│   │   └── .gitkeep
│   └── 📁 Languages/                 # Language configuration
│       └── supported_languages.json
│
├── Package.swift                     # Swift Package dependencies
├── .gitignore
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites

- **macOS** 14.0+ (Sonoma or later)
- **Xcode** 15.0+
- **Python** 3.10+
- **iPhone** running iOS 17.0+ (for testing)

### Step 1: Clone & Setup

```bash
cd TranslateLocal

# Set up Python environment for model conversion
cd MLModels
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Step 2: Convert Models

```bash
# Convert Gemma-3n-E2B to Core ML
python convert_gemma_to_coreml.py

# Or convert Opus-MT for specific language pairs
python convert_opus_to_coreml.py --source en --target ja
```

### Step 3: Open in Xcode

```bash
# Open the iOS project
open iOS/TranslateLocal.xcodeproj
```

### Step 4: Build & Run

1. Select your target device in Xcode
2. Build and run (⌘ + R)
3. First launch will download/initialize models

---

## 🔄 Model Conversion

### Gemma-3n-E2B Conversion

```python
# See MLModels/convert_gemma_to_coreml.py for full implementation
from transformers import AutoModelForCausalLM, AutoTokenizer
import coremltools as ct

# Load and convert
model = AutoModelForCausalLM.from_pretrained("google/gemma-3n-e2b-it")
# ... conversion process
coreml_model.save("Gemma3nE2B.mlpackage")
```

### Optimization for iOS

```python
# Quantization for smaller size
coreml_model = ct.convert(
    model,
    compute_precision=ct.precision.FLOAT16,  # Half precision
    compute_units=ct.ComputeUnit.ALL,        # Use Neural Engine
)
```

---

## 📅 Development Roadmap

### Phase 1: Foundation ✅ (Current)
- [x] Project structure
- [x] OCR Service implementation
- [x] Basic Translation Service
- [x] Model conversion scripts

### Phase 2: Core Features 🚧
- [ ] Camera-based translation view
- [ ] Share Extension
- [ ] Action Extension
- [ ] Settings management

### Phase 3: Polish
- [ ] UI/UX refinement
- [ ] Performance optimization
- [ ] Model caching
- [ ] Translation history

### Phase 4: Advanced Features
- [ ] Multiple model support
- [ ] Custom fine-tuning
- [ ] Batch translation
- [ ] Export/import settings

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

## 🤝 Contributing

Contributions welcome! Please read our contributing guidelines before submitting PRs.

---

<p align="center">
  <b>Built with ❤️ for privacy-focused translation</b>
</p>
