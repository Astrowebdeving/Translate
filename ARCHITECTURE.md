# 🏗️ Architecture Overview

> **Deep dive into how TranslateLocal works under the hood**

---

## 📊 High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                           TranslateLocal App                           │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│   │   Camera    │  │    Image    │  │   History   │  │  Settings   │  │
│   │    View     │  │    View     │  │    View     │  │    View     │  │
│   └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
│          │                │                │                │          │
│          └────────────────┴────────────────┴────────────────┘          │
│                                    │                                   │
│                          ┌─────────┴─────────┐                        │
│                          │    View Models    │                        │
│                          │  (State Mgmt)     │                        │
│                          └─────────┬─────────┘                        │
│                                    │                                   │
│    ┌───────────────────────────────┼───────────────────────────────┐  │
│    │                               │                               │  │
│    ▼                               ▼                               ▼  │
│  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐ │
│  │ OCR Service │           │ Translation │           │   Model     │ │
│  │  (Vision)   │──────────▶│   Service   │◀──────────│  Manager    │ │
│  └─────────────┘   text    └─────────────┘   models  └─────────────┘ │
│        │                          │                         │         │
│        │                          │                         │         │
│        ▼                          ▼                         ▼         │
│  ┌─────────────┐           ┌─────────────┐           ┌─────────────┐ │
│  │   Vision    │           │   Core ML   │           │   Bundle/   │ │
│  │  Framework  │           │   Runtime   │           │  Documents  │ │
│  │   (Apple)   │           │   (Apple)   │           │             │ │
│  └─────────────┘           └─────────────┘           └─────────────┘ │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 🔍 Component Details

### 1. OCR Service (`OCRService.swift`)

**Purpose**: Extract text from images using Apple's Vision framework

**How it works**:

```swift
// 1. Create a text recognition request
let request = VNRecognizeTextRequest { request, error in
    // Handle results
}

// 2. Configure recognition settings
request.recognitionLevel = .accurate  // or .fast
request.recognitionLanguages = ["en", "ja", "zh-Hans"]
request.usesLanguageCorrection = true

// 3. Process the image
let handler = VNImageRequestHandler(cgImage: image)
try handler.perform([request])

// 4. Extract results
let observations = request.results as? [VNRecognizedTextObservation]
for observation in observations {
    let text = observation.topCandidates(1).first?.string
    let boundingBox = observation.boundingBox  // Normalized 0-1 coordinates
}
```

**Key concepts**:
- **VNRecognizedTextObservation**: Contains detected text and its position
- **Bounding Box**: Normalized coordinates (0-1) using bottom-left origin
- **Confidence Score**: How certain Vision is about the text (0-1)
- **Recognition Level**: `.fast` for real-time, `.accurate` for static images

---

### 2. Translation Service (`TranslationService.swift`)

**Purpose**: Translate text using on-device ML models

**Translation Flow**:

```
Input Text → Tokenization → Model Inference → Decoding → Output Text
```

**Detailed steps**:

```swift
// 1. Select the best model for this language pair
func selectModel(from source: Language, to target: Language) -> TranslationModelType {
    // For English→Japanese, use specialized Opus model
    if source == .english && target == .japanese {
        return .opusEnJa
    }
    // For other pairs, use multilingual Gemma
    return .gemma3n
}

// 2. Tokenize the input
// Converts "Hello world" → [15496, 995] (token IDs)
let tokens = tokenizer.encode(text)

// 3. Create Core ML input
let inputArray = MLMultiArray(shape: [1, tokens.count])
// Fill with token IDs...

// 4. Run model inference
let output = try model.prediction(from: input)

// 5. Decode output tokens back to text
let translatedTokens = decodeLogits(output.logits)
let translatedText = tokenizer.decode(translatedTokens)
```

**Model Types**:

| Model | Type | Use Case |
|-------|------|----------|
| **Gemma-3n** | Causal LM | Multilingual, any language pair |
| **Opus-MT** | Encoder-Decoder | Specific pairs (higher quality) |

---

### 3. Model Manager (`ModelManager.swift`)

**Purpose**: Handle model loading, caching, and memory management

**Lifecycle**:

```
App Launch
    │
    ▼
┌─────────────────┐
│ Scan Available  │ ← Check Bundle & Documents directory
│     Models      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  User Selects   │
│   Translation   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ Model in Cache? │─Yes─▶│  Return Cached  │
└────────┬────────┘     └─────────────────┘
         │ No
         ▼
┌─────────────────┐
│   Load Model    │ ← MLModel.load(contentsOf:)
│   to Memory     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Add to Cache   │
│   Return Model  │
└─────────────────┘
```

**Memory Management**:

```swift
// Models are cached in memory for fast access
private var modelCache: [TranslationModelType: MLModel] = [:]

// When memory is low, unload least-used models
func optimizeMemory(targetBytes: Int64) {
    for type in loadedModels {
        if currentUsage <= targetBytes { break }
        unloadModel(type)
    }
}
```

---

### 4. Camera System (`CameraTranslateView.swift`)

**Purpose**: Real-time camera preview with text overlay

**Components**:

```
┌─────────────────────────────────────────────────────────┐
│                    Camera View                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │                                                   │  │
│  │              AVCaptureVideoPreviewLayer          │  │
│  │                                                   │  │
│  │    ┌─────────────────────────────┐               │  │
│  │    │ "Bonjour" → [こんにちは]    │ ← Text Overlay│  │
│  │    └─────────────────────────────┘               │  │
│  │                                                   │  │
│  │    ┌─────────────────┐                           │  │
│  │    │ "Menu" → [メニュー]                          │  │
│  │    └─────────────────┘                           │  │
│  │                                                   │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  [🔦 Flash]        [EN → JA]        [⏸️ Pause]         │
└─────────────────────────────────────────────────────────┘
```

**Frame Processing Pipeline**:

```swift
// Camera delegate receives frames
func captureOutput(_ output: AVCaptureOutput, 
                   didOutput sampleBuffer: CMSampleBuffer, 
                   from connection: AVCaptureConnection) {
    
    // 1. Get pixel buffer from sample
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    
    // 2. Throttle processing (every 300ms)
    guard Date().timeIntervalSince(lastProcessedTime) >= 0.3 else { return }
    
    // 3. Send to OCR service
    Task {
        let ocrResult = try await ocrService.recognizeText(from: pixelBuffer)
        
        // 4. Translate recognized text
        for block in ocrResult.textBlocks {
            let translation = try await translationService.translate(block.text)
            translatedTexts[block.id] = translation
        }
        
        // 5. Update UI
        self.recognizedBlocks = ocrResult.textBlocks
    }
}
```

---

## 🔄 Data Flow

### Translation Request Flow

```
User → View → ViewModel → Service → Core ML → Service → ViewModel → View → User

Example:
1. User points camera at "Hello"
2. CameraTranslateView captures frame
3. CameraViewModel receives pixel buffer
4. OCRService recognizes "Hello" at position (0.1, 0.2, 0.3, 0.1)
5. TranslationService translates to "こんにちは"
6. CameraViewModel updates translatedTexts dictionary
7. CameraTranslateView renders overlay at correct position
8. User sees "こんにちは" floating above "Hello"
```

### State Management (MVVM Pattern)

```swift
// View observes ViewModel
struct CameraTranslateView: View {
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        ZStack {
            CameraPreview()
            
            // Automatically updates when viewModel changes
            ForEach(viewModel.recognizedBlocks) { block in
                TextOverlay(
                    original: block.text,
                    translated: viewModel.translatedTexts[block.id]
                )
            }
        }
    }
}

// ViewModel holds state
class CameraViewModel: ObservableObject {
    @Published var recognizedBlocks: [RecognizedTextBlock] = []
    @Published var translatedTexts: [UUID: String] = [:]
    
    // When these change, SwiftUI automatically re-renders the view
}
```

---

## 🧩 Extension Architecture

### Share Extension

```
┌─────────────────────────────────────────────────────────┐
│                     Photos App                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │              [Share Button]                      │   │
│  └─────────────────────────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────┘
                            │ NSExtensionItem
                            │ (contains image data)
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  Share Extension                        │
│  ┌─────────────────────────────────────────────────┐   │
│  │  ShareViewController                             │   │
│  │  - Extract image from NSExtensionItem            │   │
│  │  - Display preview                               │   │
│  │  - Process with OCR + Translation                │   │
│  │  - Show results or open main app                 │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Action Extension

```
┌─────────────────────────────────────────────────────────┐
│                      Safari                             │
│  ┌─────────────────────────────────────────────────┐   │
│  │  "Select some text" → [Translate]                │   │
│  └─────────────────────────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────┘
                            │ Selected text string
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  Action Extension                       │
│  ┌─────────────────────────────────────────────────┐   │
│  │  ActionViewController                            │   │
│  │  - Receive selected text                         │   │
│  │  - Translate immediately                         │   │
│  │  - Display in popup overlay                      │   │
│  │  - Copy to clipboard option                      │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### 📺 Broadcast Upload Extension (Screen Translation)

The Broadcast Extension enables translating text from ANY app by capturing the screen.

```
┌─────────────────────────────────────────────────────────┐
│                   Control Center                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Long-press Record → Select TranslateLocal       │   │
│  └─────────────────────────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────┘
                            │ Screen Recording Stream
                            ▼
┌─────────────────────────────────────────────────────────┐
│              Broadcast Upload Extension                  │
│          (Separate process, 50MB memory limit)          │
│  ┌─────────────────────────────────────────────────┐   │
│  │  SampleHandler.swift                             │   │
│  │  - Receives CMSampleBuffer at 60fps              │   │
│  │  - Throttles to 1 frame per second               │   │
│  │  - Performs OCR using Vision (VNRecognizeText)   │   │
│  │  - Writes ScreenPayload to App Group container   │   │
│  └─────────────────────────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────┘
                            │ JSON file in App Group
                            ▼
┌─────────────────────────────────────────────────────────┐
│                    Main App (PiP Mode)                   │
│  ┌─────────────────────────────────────────────────┐   │
│  │  ScreenTranslationService                        │   │
│  │  - Watches App Group file for changes            │   │
│  │  - Reads OCR text from Broadcast Extension       │   │
│  │  - Runs translation using TranslationService     │   │
│  │  - Updates PiP display with results              │   │
│  └─────────────────────────────────────────────────┘   │
│                          │                              │
│                          ▼                              │
│  ┌─────────────────────────────────────────────────┐   │
│  │  PiPService                                      │   │
│  │  - Creates AVPictureInPictureController          │   │
│  │  - Renders SwiftUI view to CMSampleBuffer        │   │
│  │  - Displays floating translation window          │   │
│  │  - Persists while user browses other apps        │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Key Components:**

| Component | Purpose | Memory Limit |
|-----------|---------|--------------|
| **SampleHandler** | Receives screen frames, performs OCR | 50MB (strict) |
| **ScreenTranslationService** | Coordinates file watching & translation | Main app memory |
| **PiPService** | Manages Picture-in-Picture display | Main app memory |
| **PiPOverlayView** | SwiftUI view rendered in PiP window | N/A |

**Data Flow:**

```
Screen Frame → Throttle (1fps) → OCR → JSON File → Translation → PiP Display
     ↑                                      ↓
Broadcast Extension              ←App Group→              Main App
```

**Critical Constraints:**

1. **Memory Limit**: Broadcast Extension MUST stay under 50MB or iOS kills it silently
2. **OCR Level**: Use `.fast` instead of `.accurate` to stay within memory
3. **Latency**: Expect 1-2 second delay due to write-read-translate cycle
4. **Atomic Writes**: Use atomic file writes to prevent partial reads

---

## 🐞 Debug Logging System

### DebugLogger (`DebugLogger.swift`)

A centralized logging system for troubleshooting across the app:

```swift
// Categories for filtering logs
enum Category {
    case screenTranslation  // Screen translation flow
    case pip                // Picture-in-Picture
    case broadcast          // Broadcast Extension
    case ocr                // Text recognition
    case translation        // Translation service
    case model              // Model loading/downloading
    case appGroup           // App Group communication
}

// Log levels with emoji indicators
enum Level {
    case debug   // 🔍
    case info    // ℹ️
    case warning // ⚠️
    case error   // ❌
    case success // ✅
}
```

**Usage:**

```swift
// Log to specific category
DebugLogger.pip("PiP started successfully", level: .success)
DebugLogger.screenTranslation("Payload received with 5 blocks", level: .info)

// Retrieve logs for display
let recentLogs = DebugLogger.getRecentLogs(count: 50)
let pipLogs = DebugLogger.getRecentLogs(category: .pip)
```

**In-App Debug Panel:**

The ScreenTranslateView includes a debug panel that shows:
- PiP status and frame count
- Broadcast state
- App Group file status
- Recent activity log
- Full debug log sheet (tap 🐞 icon)

---

## ⬇️ Model Download System

### ModelDownloadView & CoreMLModelDownloader

The app supports downloading Opus-MT models from HuggingFace:

```
User Request → ModelDownloadManager → Download from HuggingFace → Extract → Store locally
                                              │
                                              ▼
                                    App Support/TranslateLocal/Models/
```

**Supported Models:**

| Model ID | Languages | Size |
|----------|-----------|------|
| opus-zh-en | Chinese → English | ~180 MB |
| opus-en-zh | English → Chinese | ~180 MB |
| opus-ja-en | Japanese → English | ~180 MB |
| opus-en-ja | English → Japanese | ~180 MB |
| opus-es-en | Spanish → English | ~150 MB |
| opus-en-es | English → Spanish | ~150 MB |
| opus-fr-en | French → English | ~150 MB |
| opus-en-fr | English → French | ~150 MB |
| opus-de-en | German → English | ~150 MB |
| opus-en-de | English → German | ~150 MB |

**Note:** Models need to be pre-converted to CoreML format and hosted. The HuggingFace URLs point to PyTorch weights which require conversion. See `MLModels/` for conversion scripts.

---

## 🔐 Privacy & Security

### Data Flow (All Local)

```
┌─────────────────────────────────────────────────────────┐
│                     YOUR IPHONE                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │                                                  │   │
│  │  Camera → OCR → Translation → Display           │   │
│  │     │        │         │          │              │   │
│  │     ▼        ▼         ▼          ▼              │   │
│  │  [Local] [Local]   [Local]    [Local]           │   │
│  │                                                  │   │
│  │         ❌ NO DATA LEAVES DEVICE ❌              │   │
│  │                                                  │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                            ╳
                     No Network Calls
                            ╳
┌─────────────────────────────────────────────────────────┐
│                    THE INTERNET                         │
└─────────────────────────────────────────────────────────┘
```

### What We DON'T Do:
- ❌ Send text to servers
- ❌ Collect analytics
- ❌ Store images remotely
- ❌ Track usage patterns
- ❌ Require account creation

### What We DO:
- ✅ Process everything on-device
- ✅ Store history locally only
- ✅ Allow complete data deletion
- ✅ Work fully offline

---

## ⚡ Performance Considerations

### Memory Budget

| Component | Typical Memory |
|-----------|----------------|
| App Base | ~50 MB |
| Opus-MT Model (one) | ~100-200 MB |
| Gemma-3n Model | ~800-1200 MB |
| Camera Buffer | ~30-50 MB |
| **Total (Opus)** | **~300 MB** |
| **Total (Gemma)** | **~1.5 GB** |

### Optimization Strategies

1. **Lazy Model Loading**: Only load models when needed
2. **Model Caching**: Keep frequently used models in memory
3. **Memory Pressure Handling**: Unload models when iOS requests memory
4. **Frame Throttling**: Process camera frames every 300ms, not every frame
5. **Async Processing**: Use Swift concurrency to avoid blocking UI

---

## 🔮 Future Architecture Considerations

### Potential Enhancements

1. **Model Quantization**: INT8 models for 4x smaller size
2. **Streaming Translation**: Word-by-word output as model generates
3. **Multi-Model Pipeline**: Chain models for better quality
4. **Custom Fine-Tuning**: Train on user's specific domain
5. **Widget Extension**: Quick translation from home screen

### Scalability Path

```
Current: Opus-MT single-pair models
    │
    ▼
Phase 2: Gemma-3n multilingual model
    │
    ▼
Phase 3: Model routing based on language pair
    │
    ▼
Phase 4: User-trainable custom models
```

---

## 📱 iPad-Specific Considerations

### Navigation Stability

To prevent glitchy transitions on iPad, all main views use:

```swift
NavigationView {
    // content
}
.navigationViewStyle(.stack)  // Forces single-column layout
```

### Screen Translation on iPad

- PiP works on iPad but requires a real device (not simulator)
- Broadcast picker may show differently on iPad
- Simulator has limited screen recording capabilities

---

## 🔧 App Group Configuration

All targets share data via App Groups:

```
App Group: group.com.translatelocal.shared
    │
    ├── screen_payload.json       ← Written by Broadcast Extension
    ├── translation_result.json   ← Written by Main App
    ├── shared_settings.json      ← Shared preferences
    └── broadcast_status.json     ← Broadcast state
```

**Targets using App Group:**
- TranslateLocal (main app)
- BroadcastExtension
- ShareExtension
- ActionExtension

---

This architecture is designed to be:
- **Modular**: Easy to swap components
- **Testable**: Services can be mocked
- **Scalable**: Add new features without major rewrites
- **Private**: No network dependencies
- **Debuggable**: Comprehensive logging throughout
