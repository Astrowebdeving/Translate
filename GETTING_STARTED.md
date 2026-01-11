# 🚀 Getting Started with TranslateLocal

> **A step-by-step guide to set up, build, and run TranslateLocal on your iPhone**

---

## 📋 Table of Contents

1. [Prerequisites](#-prerequisites)
2. [Understanding the Project](#-understanding-the-project)
3. [Setting Up Xcode Project](#-setting-up-xcode-project)
4. [Converting ML Models](#-converting-ml-models)
5. [Building and Running](#-building-and-running)
6. [Troubleshooting](#-troubleshooting)

---

## 📦 Prerequisites

### Required Software

| Software | Version | Download |
|----------|---------|----------|
| **macOS** | 14.0+ (Sonoma) | Built-in |
| **Xcode** | 15.0+ | [App Store](https://apps.apple.com/app/xcode/id497799835) |
| **Python** | 3.10+ | [python.org](https://python.org) or `brew install python` |

### Hardware Requirements

| For Development | For Testing |
|-----------------|-------------|
| Mac with Apple Silicon (M1/M2/M3) or Intel | iPhone running iOS 17+ |
| 16GB+ RAM recommended for model conversion | 6GB+ RAM on device recommended |
| 50GB+ free disk space | 2GB+ free storage |

### Install Xcode Command Line Tools

```bash
xcode-select --install
```

---

## 🧠 Understanding the Project

### What This App Does

TranslateLocal is an iOS app that:

1. **📷 Camera Translation** - Point your iPhone camera at any text (signs, menus, books) and see translations overlaid in real-time
2. **📺 Screen Translation** - Translate text from ANY app using iOS Screen Recording and a floating PiP window
3. **🖼️ Image Translation** - Select photos or screenshots to translate all text within them
4. **📤 Share Extension** - Share images from Safari, Photos, or any app to translate
5. **✂️ Action Extension** - Select text in Safari and translate with one tap
6. **⬇️ Model Downloads** - Download Opus-MT models from HuggingFace for offline translation

### How It Works (Technical Overview)

```
┌─────────────────────────────────────────────────────────────┐
│                    User Input                               │
│         (Camera Feed / Image / Text Selection)              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│               OCR Service (Vision Framework)                │
│                                                             │
│  • Apple's built-in Vision framework                        │
│  • VNRecognizeTextRequest for text detection                │
│  • Returns text blocks with positions                       │
│  • Supports 12+ languages out of the box                    │
└─────────────────────┬───────────────────────────────────────┘
                      │ Recognized text
                      ▼
┌─────────────────────────────────────────────────────────────┐
│            Translation Service (Core ML)                    │
│                                                             │
│  • Loads AI models converted to Core ML format              │
│  • Uses Apple Neural Engine for fast inference              │
│  • Gemma-3n: General multilingual translation               │
│  • Opus-MT: Specialized language pairs                      │
└─────────────────────┬───────────────────────────────────────┘
                      │ Translated text
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    SwiftUI Views                            │
│                                                             │
│  • Overlay translated text on camera preview                │
│  • Display side-by-side comparisons                         │
│  • Save to history for later reference                      │
└─────────────────────────────────────────────────────────────┘
```

### File Structure Explained

```
TranslateLocal/
│
├── iOS/                              # 📱 Main iOS App
│   ├── TranslateLocal/
│   │   │
│   │   ├── App/
│   │   │   └── TranslateLocalApp.swift     # App entry point, initializes services
│   │   │
│   │   ├── Services/                       # 🔧 Core Business Logic
│   │   │   ├── OCRService.swift            # Text recognition using Vision
│   │   │   ├── TranslationService.swift    # Translation using Core ML models
│   │   │   ├── ModelManager.swift          # Loads/unloads ML models
│   │   │   ├── ScreenTranslationService.swift # Screen translation coordinator
│   │   │   ├── PiPService.swift            # Picture-in-Picture management
│   │   │   ├── CoreMLModelDownloader.swift # Download models from HuggingFace
│   │   │   └── DebugLogger.swift           # Centralized debug logging
│   │   │
│   │   ├── Views/                          # 🎨 UI Screens
│   │   │   ├── ContentView.swift           # Main tab navigation
│   │   │   ├── CameraTranslateView.swift   # Live camera translation
│   │   │   ├── ScreenTranslateView.swift   # Screen translation with debug UI
│   │   │   ├── PiPOverlayView.swift        # PiP window content
│   │   │   ├── ImageTranslateView.swift    # Photo/screenshot translation
│   │   │   ├── ModelDownloadView.swift     # Download Opus-MT models
│   │   │   ├── HistoryView.swift           # Past translations
│   │   │   └── SettingsView.swift          # App configuration
│   │   │
│   │   ├── ViewModels/                     # 📊 State Management (MVVM)
│   │   │   ├── CameraViewModel.swift       # Camera logic
│   │   │   └── TranslationViewModel.swift  # Translation logic
│   │   │
│   │   ├── Models/                         # 📦 Data Structures
│   │   │   └── TranslationResult.swift     # Result types
│   │   │
│   │   └── Resources/
│   │       └── Info.plist                  # App permissions & config
│   │
│   ├── Shared/                             # 🔗 Shared between app & extensions
│   │   ├── AppGroupConstants.swift         # App Group configuration
│   │   └── ScreenPayload.swift             # Screen translation data models
│   │
│   ├── BroadcastExtension/                 # 📺 Screen Recording Extension
│   │   ├── SampleHandler.swift             # OCR from screen recording
│   │   ├── Info.plist
│   │   └── BroadcastExtension.entitlements
│   │
│   ├── ShareExtension/                     # 📤 iOS Share Sheet Extension
│   │   ├── ShareViewController.swift       # Handles shared images
│   │   └── Info.plist
│   │
│   └── ActionExtension/                    # ✂️ iOS Action Extension
│       ├── ActionViewController.swift      # Handles selected text
│       └── Info.plist
│
├── MLModels/                         # 🤖 Python Model Conversion
│   ├── convert_gemma_to_coreml.py    # Converts Gemma to Core ML
│   ├── convert_opus_to_coreml.py     # Converts Opus-MT to Core ML
│   ├── test_conversion.py            # Validates converted models
│   └── requirements.txt              # Python dependencies
│
└── Resources/
    ├── Languages/
    │   └── supported_languages.json  # Language configuration
    └── Models/                       # Place converted .mlpackage here
```

---

## 🛠️ Setting Up Xcode Project

### Method 1: Create Project in Xcode (Recommended)

#### Step 1: Create New iOS App

1. Open **Xcode**
2. Click **File → New → Project** (or ⌘⇧N)
3. Select **iOS → App** → Click **Next**
4. Fill in the details:
   - **Product Name**: `TranslateLocal`
   - **Team**: Select your Apple Developer account
   - **Organization Identifier**: `com.yourname` (e.g., `com.johnsmith`)
   - **Interface**: `SwiftUI`
   - **Language**: `Swift`
   - **Storage**: `None`
   - ☐ Uncheck "Include Tests" (optional)
5. Click **Next** and save to `TranslateLocal/iOS/`

#### Step 2: Replace Generated Files

1. In Xcode's Project Navigator (left sidebar), **delete** the auto-generated:
   - `ContentView.swift`
   - `TranslateLocalApp.swift`
   - Move them to Trash

2. **Drag and drop** files from Finder into Xcode:
   - Select all files from `iOS/TranslateLocal/` folder
   - Drop them into your Xcode project
   - ☑️ Check "Copy items if needed"
   - ☑️ Check "Create groups"
   - Click **Finish**

#### Step 3: Add Extensions

1. **Add Share Extension**:
   - File → New → Target
   - Select **iOS → Share Extension**
   - Name: `ShareExtension`
   - Click **Finish**
   - When prompted "Activate scheme?", click **Activate**
   - Replace generated files with our `ShareExtension/` files

2. **Add Action Extension**:
   - File → New → Target
   - Select **iOS → Action Extension**
   - Action Type: "Presents User Interface"
   - Name: `ActionExtension`
   - Click **Finish**
   - Replace generated files with our `ActionExtension/` files

#### Step 4: Configure App Capabilities

1. Click on your project (blue icon) in the navigator
2. Select the **TranslateLocal** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** and add:
   - **App Groups** → Add `group.com.translatelocal.shared`
   - **Background Modes** → Check "Audio, AirPlay, and Picture in Picture"
   - **Background Modes** → Check "Background processing"

5. Repeat for all extension targets (ShareExtension, ActionExtension, BroadcastExtension):
   - Add same **App Groups** identifier

#### Step 4.5: Add Broadcast Upload Extension (for Screen Translation)

1. **File → New → Target**
2. Select **iOS → Broadcast Upload Extension**
3. Name: `BroadcastExtension`
4. Click **Finish**
5. When prompted "Activate scheme?", click **Activate**
6. Replace generated files with our `BroadcastExtension/` files
7. Add **App Groups** capability with `group.com.translatelocal.shared`

#### Step 5: Update Info.plist

The `Info.plist` file we created includes:
- `NSCameraUsageDescription` - Camera permission
- `NSPhotoLibraryUsageDescription` - Photo library permission

Make sure these are in your project's Info.plist or the app will crash!

#### Step 6: Set Deployment Target

1. Select your project
2. Under **General** tab
3. Set **Minimum Deployments** → iOS 17.0

---

## 🤖 Converting ML Models

### Option A: Start with Smaller Opus-MT Models (Recommended for First Run)

Opus-MT models are smaller (~50MB each) and easier to work with:

```bash
# Navigate to MLModels directory
cd /Users/tu15/Documents/ExtraProject/TranslateLocal/MLModels

# Create virtual environment
python3 -m venv venv

# Activate it
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Convert English→Japanese model (smallest, ~50MB)
python convert_opus_to_coreml.py --source en --target ja --output-dir ../Resources/Models

# Test the conversion
python test_conversion.py --model-path ../Resources/Models/OpusMT_en_ja.mlpackage
```

### Option B: Convert Gemma-3n (Full Multilingual)

⚠️ **Warning**: Requires 16GB+ RAM and may take 30+ minutes

```bash
# Make sure you're in the virtual environment
source venv/bin/activate

# Convert Gemma (this downloads ~2GB and converts)
python convert_gemma_to_coreml.py --output-dir ../Resources/Models

# Test it
python test_conversion.py --model-path ../Resources/Models/Gemma3nE2B.mlpackage
```

### Adding Models to Xcode

1. In Finder, locate the `.mlpackage` file in `Resources/Models/`
2. Drag it into your Xcode project
3. ☑️ Check "Copy items if needed"
4. ☑️ Make sure your app target is selected
5. Click **Finish**

Xcode will automatically compile the model when you build.

---

## 🏃 Building and Running

### On Simulator (Limited Features)

```
⚠️ Note: Camera features won't work on Simulator
         Use for testing UI and basic translation logic only
```

1. Select a simulator from the device dropdown (e.g., "iPhone 15 Pro")
2. Click **Run** (▶️) or press ⌘R
3. App will build and launch in simulator

### On Physical iPhone (Full Features)

1. **Connect your iPhone** via USB
2. **Trust the computer** on your iPhone if prompted
3. **Select your iPhone** from the device dropdown
4. First time setup:
   - Go to iPhone **Settings → General → VPN & Device Management**
   - Trust your developer certificate
5. Click **Run** (▶️) or press ⌘R

### First Launch

1. App will ask for **Camera permission** - Allow
2. App will ask for **Photo Library permission** - Allow
3. Onboarding screens will appear
4. Start translating! 🎉

---

## 🔧 Troubleshooting

### Common Issues

#### ❌ "No such module 'Vision'" or build errors

**Solution**: Make sure deployment target is iOS 17.0+

```
Project → Target → General → Minimum Deployments → iOS 17.0
```

#### ❌ Camera shows black screen

**Solutions**:
1. Test on a **real device**, not Simulator
2. Check camera permission in Settings
3. Make sure another app isn't using the camera

#### ❌ "Model not found" error

**Solutions**:
1. Ensure `.mlpackage` is added to the Xcode project
2. Check it's included in the target's **Build Phases → Copy Bundle Resources**
3. Try cleaning build folder: **Product → Clean Build Folder** (⇧⌘K)

#### ❌ Python conversion fails with memory error

**Solutions**:
1. Close other applications to free RAM
2. Use swap file: `sudo sysctl vm.swapusage`
3. Try the smaller Opus-MT models instead of Gemma

#### ❌ App crashes on launch

**Solutions**:
1. Check Info.plist has all required privacy descriptions
2. Look at crash logs in Xcode's **Window → Devices and Simulators**
3. Try deleting app from device and reinstalling

#### ❌ Extensions don't appear in share sheet

**Solutions**:
1. Make sure extension targets are added to the project
2. Check App Groups are configured identically for all targets
3. Restart your iPhone after installing

#### ❌ Screen translation PiP doesn't appear

**Solutions**:
1. Test on a **real device** - simulator has limited PiP support
2. Check Background Modes capability includes "Audio, AirPlay, and Picture in Picture"
3. Make sure no other PiP window is active
4. Check debug logs for errors (tap 🐞 icon)

#### ❌ Broadcast Extension not in screen recording list

**Solutions**:
1. Ensure BroadcastExtension target is built and included
2. Check the `preferredExtension` bundle ID in `ScreenTranslateView.swift` matches your extension
3. Restart device after first install
4. Verify BroadcastExtension has proper `NSExtensionPointIdentifier` in Info.plist

#### ❌ Screen translation shows "File doesn't exist"

**Solutions**:
1. Start the screen recording from Control Center
2. Make sure you selected "TranslateLocal Screen" (not just screen record)
3. Check App Group container is accessible (see debug logs)
4. Verify both main app and extension have same App Group ID

#### ❌ iPad navigation is glitchy

**Solutions**:
1. Views should use `.navigationViewStyle(.stack)` modifier
2. Check for proper NavigationView/NavigationStack usage
3. Avoid nested NavigationViews

### Getting Help

- Check Apple's [Core ML Documentation](https://developer.apple.com/documentation/coreml)
- Vision Framework: [Text Recognition Guide](https://developer.apple.com/documentation/vision/recognizing_text_in_images)
- SwiftUI: [Apple Tutorials](https://developer.apple.com/tutorials/swiftui)
- ReplayKit: [Broadcast Extension Guide](https://developer.apple.com/documentation/replaykit/broadcast_upload_extension)
- Picture-in-Picture: [AVKit PiP Guide](https://developer.apple.com/documentation/avkit/adopting_picture_in_picture_in_a_standard_player)

---

## 📱 Testing Checklist

Before releasing, test these features:

### Core Features
- [ ] Camera translation works in good lighting
- [ ] Camera translation works in low light (flash)
- [ ] Image picker loads photos correctly
- [ ] Share extension appears when sharing images
- [ ] Action extension appears when selecting text in Safari
- [ ] Translation history saves and loads
- [ ] Language switching works
- [ ] App works offline (airplane mode)
- [ ] Settings persist after restart

### Screen Translation (requires real device)
- [ ] Screen Translation tab appears in app
- [ ] "Start Screen Translation" button works
- [ ] PiP window appears after starting
- [ ] Broadcast picker shows TranslateLocal option
- [ ] Debug panel shows status updates
- [ ] Debug log sheet opens (tap 🐞 icon)
- [ ] Screen translation works with Safari
- [ ] PiP persists when switching apps

### Model Downloads
- [ ] Model download view accessible from Settings
- [ ] Available models list displays correctly
- [ ] Download progress shows
- [ ] Downloaded models appear in "Downloaded" section
- [ ] Delete model works

---

## 🐞 Debugging Screen Translation

If screen translation isn't working, use the built-in debug tools:

### View Debug Panel
1. Go to Screen Translation tab
2. Tap "Start Screen Translation"
3. Observe the debug section showing:
   - PiP Status
   - Broadcast state
   - File existence in App Group
   - Recent activity log

### View Full Debug Logs
1. While screen translation is active, tap the 🐞 bug icon in the top-left
2. This opens the Debug Log Sheet showing:
   - All recent log entries by category
   - App Group container info
   - Service-specific debug logs

### Common Issues
- **"PiP not possible"**: Try again, ensure no other PiP is active
- **"File doesn't exist"**: Broadcast Extension hasn't started recording
- **Simulator limitations**: Screen recording doesn't work on simulator

---

## 🎉 You're Ready!

Once you've completed these steps, you'll have a fully functional on-device translation app. 

**Features available:**
1. ✅ Camera-based real-time translation
2. ✅ Image/screenshot translation
3. ✅ Screen translation with PiP (real device only)
4. ✅ Share & Action extensions
5. ✅ Model download from HuggingFace
6. ✅ Built-in debug logging

**Next steps to enhance your app:**
1. Convert and host CoreML models for real translation
2. Add more language pairs
3. Customize the UI theme
4. Add text-to-speech for translations

Happy coding! 🚀
