# 🚀 TranslateLocal - Project Completion Guide

> **A comprehensive step-by-step guide to finish building your on-device translation app**

---

## 📋 Table of Contents

1. [Current Status](#-current-status)
2. [Phase 1: Xcode Project Setup](#-phase-1-xcode-project-setup)
3. [Phase 2: ML Model Conversion](#-phase-2-ml-model-conversion)
4. [Phase 3: Build & Test](#-phase-3-build--test)
5. [Phase 4: Polish & Features](#-phase-4-polish--features)
6. [Phase 5: Release Preparation](#-phase-5-release-preparation)
7. [Troubleshooting](#-troubleshooting)

---

## 📊 Current Status

### ✅ Completed
- [x] Project structure and architecture
- [x] OCR Service (Vision Framework integration)
- [x] Translation Service (Core ML integration)
- [x] Model Manager (loading, caching, lifecycle)
- [x] All Views (Camera, Image, History, Settings)
- [x] All ViewModels (MVVM pattern)
- [x] Share Extension code
- [x] Action Extension code
- [x] Backward compatibility utilities
- [x] ML conversion scripts (Gemma + Opus-MT)
- [x] Entitlements files
- [x] Info.plist configurations
- [x] Xcode setup automation script

### 🚧 Needs Completion
- [ ] Extension targets in Xcode
- [ ] App Groups capability setup
- [ ] Converted ML model(s)
- [ ] Testing on physical device
- [ ] UI polish and animations

---

## 🛠️ Phase 1: Xcode Project Setup

**Estimated Time: 15-30 minutes**

### Step 1.1: Run the Setup Script

```bash
cd /Users/tu15/Developer/TranslateLocal
./scripts/setup_xcode_project.sh
```

This script will:
- Create/update all entitlements files
- Configure Info.plist files for extensions
- Generate an XcodeGen project specification
- Create setup instructions

### Step 1.2: Choose Your Setup Method

#### Option A: Using XcodeGen (Recommended) 🌟

```bash
# Install XcodeGen if not already installed
brew install xcodegen

# Generate the Xcode project
cd /Users/tu15/Developer/TranslateLocal
xcodegen generate
```

This will create a fresh, properly configured Xcode project.

#### Option B: Manual Setup in Xcode

Open Xcode and follow `XCODE_SETUP_INSTRUCTIONS.md` which was created by the script.

### Step 1.3: Configure Signing

1. Open `TranslateLocal.xcodeproj` in Xcode
2. For **each target** (TranslateLocal, ShareExtension, ActionExtension):
   - Select the target in Project Navigator
   - Go to **Signing & Capabilities**
   - Select your **Team** from the dropdown
   - Xcode will auto-generate provisioning profiles

### Step 1.4: Set Up App Groups

For **each target**, add the App Groups capability:

1. Select target → **Signing & Capabilities** → **+ Capability**
2. Choose **App Groups**
3. Add: `group.com.translatelocal.shared`

**Important:** The App Group identifier must be identical across all three targets!

### Step 1.5: Verify Project Structure

After setup, your project should have:

```
TranslateLocal.xcodeproj
├── TranslateLocal (target)
│   ├── App/
│   ├── Views/
│   ├── ViewModels/
│   ├── Services/
│   ├── Models/
│   └── Utilities/
├── ShareExtension (target)
│   └── ShareViewController.swift
└── ActionExtension (target)
    └── ActionViewController.swift
```

---

## 🤖 Phase 2: ML Model Conversion

**Estimated Time: 30 minutes - 2 hours (depending on model size)**

### Step 2.1: Set Up Python Environment

```bash
cd /Users/tu15/Developer/TranslateLocal/MLModels

# Create virtual environment
python3 -m venv venv

# Activate it
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Step 2.2: Choose Your Model Strategy

| Strategy | Pros | Cons | Best For |
|----------|------|------|----------|
| **Opus-MT First** | Small (~50MB), fast conversion | One model per language pair | Quick testing, limited languages |
| **Gemma-3n** | Multilingual (35+ languages) | Large (~800MB), needs 16GB+ RAM | Production use |
| **Both** | Best quality & coverage | More storage | Full-featured app |

### Step 2.3A: Convert Opus-MT (Start Here)

Best for initial testing. Convert English→Japanese first:

```bash
# Make sure you're in the virtual environment
source venv/bin/activate

# Convert EN→JA model
python convert_opus_to_coreml.py \
    --source en \
    --target ja \
    --output-dir ../Resources/Models

# Convert more language pairs as needed
python convert_opus_to_coreml.py --source en --target zh --output-dir ../Resources/Models
python convert_opus_to_coreml.py --source en --target es --output-dir ../Resources/Models
python convert_opus_to_coreml.py --source en --target fr --output-dir ../Resources/Models
python convert_opus_to_coreml.py --source en --target de --output-dir ../Resources/Models
python convert_opus_to_coreml.py --source en --target ko --output-dir ../Resources/Models
```

### Step 2.3B: Convert Gemma-3n (For Production)

⚠️ **Requirements:** 16GB+ RAM, 50GB+ disk space, ~30 min conversion time

```bash
source venv/bin/activate

# Convert with float16 quantization (recommended)
python convert_gemma_to_coreml.py \
    --model-name google/gemma-3n-e2b-it \
    --output-dir ../Resources/Models \
    --quantize float16 \
    --max-length 512

# Or with int8 for smaller size (reduced quality)
python convert_gemma_to_coreml.py \
    --quantize int8 \
    --output-dir ../Resources/Models
```

### Step 2.4: Add Models to Xcode

1. In Finder, locate the `.mlpackage` files in `Resources/Models/`
2. Drag them into your Xcode project
3. When prompted:
   - ☑️ "Copy items if needed"
   - ☑️ Select **TranslateLocal** target (main app only)
4. Xcode will compile the models during build

### Step 2.5: Verify Models are Bundled

1. Select your model in Project Navigator
2. In the File Inspector (right panel), verify:
   - **Target Membership**: TranslateLocal is checked
   - The model will appear in **Build Phases → Copy Bundle Resources**

---

## 🏃 Phase 3: Build & Test

**Estimated Time: 30-60 minutes**

### Step 3.1: Build for Simulator

```
⚠️ Note: Camera features won't work on Simulator
         Use Simulator for testing UI and OCR with static images
```

1. Select **iPhone 15 Pro** (or similar) from device dropdown
2. Press **⌘B** to build
3. Fix any build errors (see Troubleshooting below)
4. Press **⌘R** to run

### Step 3.2: Test on Physical Device

1. Connect iPhone via USB
2. Trust the computer if prompted
3. Select your iPhone from device dropdown
4. Press **⌘R** to run
5. On first run, grant permissions when prompted:
   - Camera access
   - Photo library access

### Step 3.3: Test Checklist

#### Core Features
- [ ] **Onboarding** - Swipe through 3 pages, tap "Get Started"
- [ ] **Camera Tab** - Preview shows, text detection works
- [ ] **Image Tab** - Can select photos, OCR extracts text
- [ ] **History Tab** - Translations are saved and searchable
- [ ] **Settings Tab** - All options work, settings persist

#### Translation (requires ML model)
- [ ] Camera text gets translated overlay
- [ ] Image text gets translated
- [ ] Language switching works
- [ ] Translation appears in history

#### Extensions (requires device install)
- [ ] Share Extension appears when sharing images
- [ ] Action Extension appears when selecting text in Safari

### Step 3.4: Testing Extensions

**Share Extension:**
1. Open Photos app
2. Select an image with text
3. Tap Share → look for "Translate"
4. Extension should appear and process image

**Action Extension:**
1. Open Safari
2. Navigate to any webpage
3. Select some text
4. Tap "Translate" in the selection menu

---

## ✨ Phase 4: Polish & Features

**Estimated Time: Variable**

### Step 4.1: Essential Polish

1. **App Icon**
   - Create icons at required sizes (see Assets.xcassets)
   - Use SF Symbols or custom design
   - Consider using an AI tool to generate

2. **Launch Screen**
   - Update `LaunchScreen.storyboard` or use SwiftUI
   - Keep it simple (logo + app name)

3. **Error Handling**
   - Add user-friendly error messages
   - Handle edge cases (no camera, no photos, etc.)

### Step 4.2: Recommended Enhancements

```swift
// Add haptic feedback for translations
import UIKit

func triggerHaptic() {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
}
```

```swift
// Add accessibility labels
Text(translatedText)
    .accessibilityLabel("Translation: \(translatedText)")
    .accessibilityHint("Double tap to copy")
```

### Step 4.3: Performance Optimization

1. **Model Loading**
   - Load models on background thread
   - Show loading indicator
   - Cache loaded models

2. **Camera Processing**
   - Already throttled at 300ms (adjustable in CameraTranslateView)
   - Reduce if device heats up

3. **Memory Management**
   - App already handles memory warnings
   - Unload unused models when needed

---

## 📱 Phase 5: Release Preparation

**Estimated Time: 1-2 hours**

### Step 5.1: App Store Connect Setup

1. Log into [App Store Connect](https://appstoreconnect.apple.com)
2. Create new App:
   - **Name**: TranslateLocal
   - **Bundle ID**: oceania1984.InIndiana.AWT.TranslateLocal
   - **SKU**: translatelocal-001

### Step 5.2: Privacy Labels

In App Store Connect, declare:
- **Data Not Collected** (if true)
- No tracking, analytics, or data collection

### Step 5.3: App Description

```
TranslateLocal - Private On-Device Translation

Translate any text instantly using AI that runs entirely on your device.

✨ KEY FEATURES:
• Camera Translation - Point at signs, menus, books for instant translation
• Image Translation - Translate text in screenshots and photos
• 100% Offline - Works without internet connection
• Complete Privacy - Your text never leaves your device
• No Subscriptions - One-time download, unlimited use

🌍 SUPPORTED LANGUAGES:
English, Japanese, Chinese, Korean, Spanish, French, German, and more!

🔒 PRIVACY FIRST:
All translation happens on-device using compact AI models. No data is ever sent to external servers.
```

### Step 5.4: Screenshots

Required sizes:
- 6.7" (iPhone 15 Pro Max): 1290 x 2796
- 6.5" (iPhone 14 Plus): 1242 x 2688
- 5.5" (iPhone 8 Plus): 1242 x 2208
- iPad Pro 12.9": 2048 x 2732

### Step 5.5: Archive & Upload

1. Select **Any iOS Device** as target
2. **Product → Archive**
3. In Organizer, click **Distribute App**
4. Choose **App Store Connect**
5. Follow prompts to upload

---

## 🔧 Troubleshooting

### Build Errors

**"No such module 'Vision'"**
- Ensure deployment target is iOS 17.0+
- Clean build folder: **Product → Clean Build Folder**

**"Model not found"**
- Verify .mlpackage is in Copy Bundle Resources
- Check model name matches code exactly

**"Signing error"**
- Select development team in Signing & Capabilities
- Enable automatic signing

### Runtime Errors

**Camera black screen**
- Test on physical device, not Simulator
- Check NSCameraUsageDescription in Info.plist

**Extensions not appearing**
- Verify App Groups are configured identically
- Check extension bundle identifiers
- Restart device after install

**Translation not working**
- Verify ML model is bundled
- Check ModelManager.swift for model loading errors
- Look at Xcode console for error messages

### Memory Issues

**App crashes during translation**
- Use smaller models (Opus-MT instead of Gemma)
- Ensure device has 6GB+ RAM
- Test on newer iPhone models

---

## 📞 Quick Reference

### File Locations

| File | Purpose |
|------|---------|
| `iOS/TranslateLocal/App/TranslateLocalApp.swift` | App entry point |
| `iOS/TranslateLocal/Services/OCRService.swift` | Text recognition |
| `iOS/TranslateLocal/Services/TranslationService.swift` | ML translation |
| `iOS/TranslateLocal/Services/ModelManager.swift` | Model lifecycle |
| `Resources/Models/` | Converted ML models |
| `MLModels/` | Python conversion scripts |

### Key Commands

```bash
# Run setup script
./scripts/setup_xcode_project.sh

# Convert Opus model
python MLModels/convert_opus_to_coreml.py --source en --target ja

# Convert Gemma model
python MLModels/convert_gemma_to_coreml.py --quantize float16

# Generate Xcode project (if using XcodeGen)
xcodegen generate
```

### Support Resources

- [Apple Vision Framework](https://developer.apple.com/documentation/vision)
- [Core ML Documentation](https://developer.apple.com/documentation/coreml)
- [App Extensions Guide](https://developer.apple.com/app-extensions/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)

---

## ✅ Completion Checklist

```
□ Phase 1: Xcode Setup
  □ Run setup script
  □ Configure extension targets
  □ Set up App Groups
  □ Configure signing

□ Phase 2: ML Models
  □ Set up Python environment
  □ Convert at least one model
  □ Add model to Xcode project

□ Phase 3: Testing
  □ Build succeeds
  □ Simulator test passes
  □ Physical device test passes
  □ Extensions work

□ Phase 4: Polish
  □ App icon added
  □ Launch screen configured
  □ Error handling complete

□ Phase 5: Release
  □ App Store Connect configured
  □ Screenshots prepared
  □ App archived and uploaded
```

---

**🎉 Congratulations on building TranslateLocal!**

*Built with ❤️ for privacy-focused translation*
