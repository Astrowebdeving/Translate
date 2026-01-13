# 🤖 MLX Swift + Gemma 3n Integration Plan

## Overview

This document provides a complete implementation plan for integrating Apple's MLX Swift framework with Gemma 3n model into the TranslateLocal iOS app. Another AI assistant (Claude Opus 4.5) should follow this plan carefully.

---

## 📋 Current App Architecture

### Existing Services (DO NOT MODIFY unless specified)
- `TranslationService.swift` - Main translation service using CoreML models
- `ModelManager.swift` - Manages CoreML model loading/caching
- `CoreMLModelDownloader.swift` - Downloads CoreML models from HuggingFace
- `PiPService.swift` - Picture-in-Picture overlay service
- `OCRService.swift` - Text recognition from images

### Key Data Types (Already Defined)
```swift
struct TranslationResult  // In TranslationService.swift
struct Language           // In TranslationService.swift  
enum TranslationModelType // In TranslationService.swift (includes .gemma3n case)
```

### Current Gemma References
The app already has a `.gemma3n` case in `TranslationModelType` but it's designed for CoreML. We need a **parallel MLX-based implementation** that works alongside the existing CoreML infrastructure.

---

## 🎯 Goals

1. **Add MLX Swift packages** to the project
2. **Create MLXModelManager.swift** - Download and manage MLX models from HuggingFace
3. **Create GemmaService.swift** - Provide Gemma 3n inference via MLX
4. **Update UI** - Add Gemma download option in ModelDownloadView
5. **Integrate with PiPService** - Use Gemma for smart PiP features

---

## 📦 Phase 1: Add MLX Swift Dependencies

### Step 1.1: Update `project.yml`

Add these packages to the `TranslateLocal` target:

```yaml
packages:
  ZIPFoundation:
    url: https://github.com/weichsel/ZIPFoundation
    from: 0.9.0
  MLX:
    url: https://github.com/ml-explore/mlx-swift
    from: 0.30.0
  MLXLM:
    url: https://github.com/ml-explore/mlx-swift-lm
    from: 0.1.0
```

And add to dependencies:
```yaml
dependencies:
  - package: ZIPFoundation
  - package: MLX
    product: MLX
  - package: MLX
    product: MLXNN
  - package: MLXLM
```

### Step 1.2: Regenerate Xcode Project

After updating `project.yml`, run:
```bash
xcodegen generate
```

---

## 📦 Phase 2: Create MLXModelManager.swift

Create a new file: `iOS/TranslateLocal/Services/MLXModelManager.swift`

### Purpose
- Download Gemma 3n MLX model from HuggingFace (`mlx-community/gemma-3n-E2B-it-lm-4bit`)
- Cache model files in Application Support directory
- Provide model loading for GemmaService

### Key Requirements
1. Use `URLSession` for downloading (supports progress tracking)
2. Store in `ApplicationSupport/TranslateLocal/MLXModels/gemma-3n-e2b/`
3. Track download state with `@Observable`
4. Implement `isGemmaDownloaded()` check

### Model Info
- **HuggingFace Repo**: `mlx-community/gemma-3n-E2B-it-lm-4bit`
- **Files to download**:
  - `config.json`
  - `model.safetensors` (or shards)
  - `tokenizer.json`
  - `tokenizer_config.json`
- **Approximate size**: ~1.5GB (4-bit quantized)

### Skeleton Structure
```swift
import Foundation
import MLX
import MLXLM

@MainActor @Observable
class MLXModelManager {
    static let shared = MLXModelManager()
    
    private(set) var isDownloading = false
    private(set) var downloadProgress: Double = 0
    private(set) var isGemmaReady = false
    private(set) var error: String?
    
    private let modelsDirectory: URL
    private let gemmaModelId = "mlx-community/gemma-3n-E2B-it-lm-4bit"
    
    // Download Gemma model files from HuggingFace
    func downloadGemma() async throws { }
    
    // Check if Gemma is already downloaded
    func checkGemmaStatus() { }
    
    // Get local path to Gemma model
    func gemmaModelPath() -> URL? { }
    
    // Delete downloaded model
    func deleteGemma() throws { }
}
```

---

## 📦 Phase 3: Create GemmaService.swift

Create a new file: `iOS/TranslateLocal/Services/GemmaService.swift`

### Purpose
- Load Gemma 3n model using MLX Swift
- Provide translation via prompting
- Provide general LLM capabilities for PiP management
- Support streaming text generation

### Key Imports
```swift
import Foundation
import MLX
import MLXNN
import MLXRandom
import MLXLM  // From mlx-swift-lm package
```

### Key Methods

#### 1. Translation
```swift
func translate(text: String, to targetLanguage: String) async throws -> String
```
Uses prompt: `"Translate the following text to {language}. Only output the translation, nothing else:\n\n{text}"`

#### 2. Smart PiP Content Analysis
```swift
func analyzeScreenContent(ocrTexts: [String]) async throws -> ScreenAnalysis
```
Returns structured analysis of what's on screen (headers, buttons, content type)

#### 3. Streaming Generation
```swift
func generateStream(prompt: String) -> AsyncThrowingStream<String, Error>
```
For real-time text generation with UI updates

### Skeleton Structure
```swift
import Foundation
import MLX
import MLXNN
import MLXLM

/// Gemma 3n service using MLX for on-device inference
@MainActor @Observable
class GemmaService {
    static let shared = GemmaService()
    
    private(set) var isLoaded = false
    private(set) var isProcessing = false
    private(set) var error: String?
    
    private var model: LLMModel?
    private var tokenizer: Tokenizer?
    private let mlxManager = MLXModelManager.shared
    
    // Load the Gemma model into memory
    func loadModel() async throws { }
    
    // Unload to free memory
    func unloadModel() { }
    
    // Translate text
    func translate(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String
    ) async throws -> String { }
    
    // Analyze screen content for PiP
    func analyzeForPiP(textBlocks: [String]) async throws -> PiPAnalysis { }
    
    // General text generation
    func generate(prompt: String, maxTokens: Int) async throws -> String { }
    
    // Streaming generation
    func generateStream(prompt: String) -> AsyncThrowingStream<String, Error> { }
}

struct PiPAnalysis {
    let summary: String
    let contentType: String  // "article", "chat", "menu", etc.
    let suggestedActions: [String]
}
```

---

## 📦 Phase 4: Update TranslationService.swift

### Modify `performTranslation` Method

Add a check to use GemmaService when `.gemma3n` model type is selected:

```swift
private func performTranslation(
    text: String,
    from sourceLanguage: Language,
    to targetLanguage: Language,
    using modelType: TranslationModelType
) async throws -> String {
    
    // NEW: Check if Gemma via MLX should be used
    if modelType == .gemma3n && GemmaService.shared.isLoaded {
        return try await GemmaService.shared.translate(
            text: text,
            from: sourceLanguage.name,
            to: targetLanguage.name
        )
    }
    
    // Existing CoreML-based translation...
    guard let model = models[modelType] else {
        return try demoTranslation(text: text, from: sourceLanguage, to: targetLanguage)
    }
    // ... rest of existing code
}
```

### Update `translateWithPositioning` Method

Use GemmaService for smart positioning:

```swift
if GemmaService.shared.isLoaded {
    // Use Gemma for intelligent positioning
    return try await performGemmaPositionedTranslation(...)
}
```

---

## 📦 Phase 5: Update PiPService.swift

### Add Gemma Integration for Smart PiP

Add method to analyze screen content:

```swift
/// Analyze current screen content using Gemma
func analyzeScreenWithGemma() async throws -> PiPAnalysis? {
    guard GemmaService.shared.isLoaded else { return nil }
    
    let texts = positionedTranslations.map { $0.originalText }
    return try await GemmaService.shared.analyzeForPiP(textBlocks: texts)
}
```

Add smart overlay mode that uses Gemma analysis:

```swift
/// Smart overlay mode using Gemma
var smartOverlayEnabled: Bool = false

func enableSmartOverlay() async {
    guard GemmaService.shared.isLoaded else {
        DebugLogger.pip("Gemma not loaded, cannot enable smart overlay", level: .warning)
        return
    }
    smartOverlayEnabled = true
}
```

---

## 📦 Phase 6: Update ModelDownloadView.swift

### Add Gemma Download Section

Add a new section to the view:

```swift
// Gemma 3n Section
Section("Gemma 3n (Multilingual AI)") {
    GemmaDownloadRow()
}
```

Create `GemmaDownloadRow` view:

```swift
struct GemmaDownloadRow: View {
    @State private var mlxManager = MLXModelManager.shared
    @State private var gemmaService = GemmaService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Gemma 3n E2B")
                        .font(.headline)
                    Text("Any language pair • Smart PiP features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if mlxManager.isDownloading {
                    ProgressView(value: mlxManager.downloadProgress)
                        .frame(width: 60)
                } else if mlxManager.isGemmaReady {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Button("Download") {
                        Task { try await mlxManager.downloadGemma() }
                    }
                }
            }
            
            if mlxManager.isGemmaReady {
                HStack {
                    Text("~1.5 GB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Delete", role: .destructive) {
                        try? mlxManager.deleteGemma()
                    }
                    .font(.caption)
                }
            }
        }
    }
}
```

---

## 📦 Phase 7: Memory Management

### Important Considerations

1. **Gemma requires ~3GB RAM** when loaded
2. **Unload when not needed** to prevent crashes on lower-end devices
3. **Never load both large CoreML models AND Gemma simultaneously**

### Add to GemmaService

```swift
/// Automatically unload Gemma if memory pressure is detected
private func setupMemoryWarningObserver() {
    NotificationCenter.default.addObserver(
        forName: UIApplication.didReceiveMemoryWarningNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.unloadModel()
        DebugLogger.model("Unloaded Gemma due to memory warning", level: .warning)
    }
}
```

---

## 📁 File Structure After Implementation

```
iOS/TranslateLocal/Services/
├── AppleTranslationService.swift  (existing)
├── CoreMLModelDownloader.swift    (existing)
├── GemmaService.swift             (NEW)
├── GlossaryService.swift          (existing)
├── MLXModelManager.swift          (NEW)
├── ModelManager.swift             (existing)
├── ModelTokenizer.swift           (existing)
├── OCRService.swift               (existing)
├── PiPService.swift               (modify)
├── ScreenTranslationService.swift (existing)
└── TranslationService.swift       (modify)
```

---

## 🧪 Testing Checklist

### Unit Tests
- [ ] MLXModelManager downloads model correctly
- [ ] GemmaService loads model without crash
- [ ] Translation produces valid output
- [ ] Memory is freed when unloading

### Integration Tests
- [ ] Gemma translation works alongside Opus models
- [ ] PiP overlay displays Gemma translations
- [ ] App doesn't crash on iPhone with 4GB RAM
- [ ] Download can be cancelled and resumed

### Device Tests
- [ ] iPhone 13 (4GB RAM) - Should work with 4-bit model
- [ ] iPhone 15 Pro (8GB RAM) - Should work smoothly
- [ ] iPad Pro - Should work excellently

---

## ⚠️ Critical Notes for Implementation

1. **DO NOT use `trust_remote_code=True`** - security risk
2. **Always handle errors gracefully** - model loading can fail
3. **Provide fallback** - if Gemma fails, fall back to Opus or demo mode
4. **Log extensively** - use `DebugLogger` for troubleshooting
5. **Test on real device** - Simulator may not reflect true performance
6. **Use 4-bit quantized model** - `gemma-3n-E2B-it-lm-4bit` not bf16

---

## 📚 Reference Documentation

- [MLX Swift GitHub](https://github.com/ml-explore/mlx-swift)
- [MLX Swift Examples](https://github.com/ml-explore/mlx-swift-examples)
- [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm)
- [Gemma 3n MLX Models](https://huggingface.co/collections/mlx-community/gemma-3n)
- [HuggingFace: gemma-3n-E2B-it-lm-4bit](https://huggingface.co/mlx-community/gemma-3n-E2B-it-lm-4bit)

---

## 🚀 Implementation Order

1. **Phase 1** - Add packages to project.yml, regenerate project
2. **Phase 2** - Create MLXModelManager.swift
3. **Phase 3** - Create GemmaService.swift
4. **Phase 6** - Update ModelDownloadView (test download works)
5. **Phase 4** - Update TranslationService (test translation works)
6. **Phase 5** - Update PiPService (test smart features)
7. **Phase 7** - Add memory management
8. **Test everything**

---

*This plan was created on 2026-01-12. Gemma 3n E2B is a 5B parameter multimodal model from Google, converted to MLX format by the mlx-community.*
