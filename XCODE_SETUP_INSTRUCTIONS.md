# 🛠️ Xcode Manual Setup Instructions

If you're not using XcodeGen, follow these steps to configure the project manually.

## Step 1: Create Share Extension Target

1. Open `TranslateLocal.xcodeproj` in Xcode
2. Click **File → New → Target**
3. Select **iOS → Share Extension**
4. Configure:
   - **Product Name**: `ShareExtension`
   - **Team**: Select your developer team
   - **Language**: Swift
   - **Project**: TranslateLocal
   - **Embed in Application**: TranslateLocal
5. Click **Finish**
6. When asked "Activate scheme?", click **Cancel**
7. **Delete** the auto-generated Swift file (you'll use the existing one)

## Step 2: Create Action Extension Target

1. Click **File → New → Target**
2. Select **iOS → Action Extension**
3. Configure:
   - **Product Name**: `ActionExtension`
   - **Action Type**: Presents User Interface
   - **Team**: Select your developer team
   - **Language**: Swift
4. Click **Finish**, then **Cancel** on scheme activation
5. **Delete** auto-generated files

## Step 3: Add Existing Files to Extension Targets

### For ShareExtension:
1. Select the ShareExtension group in Project Navigator
2. Right-click → **Add Files to "TranslateLocal"**
3. Navigate to `iOS/ShareExtension/`
4. Select:
   - `ShareViewController.swift`
5. ☑️ Check only **ShareExtension** in "Add to targets"
6. Click **Add**

### For ActionExtension:
1. Select the ActionExtension group in Project Navigator
2. Right-click → **Add Files to "TranslateLocal"**
3. Navigate to `iOS/ActionExtension/`
4. Select:
   - `ActionViewController.swift`
5. ☑️ Check only **ActionExtension** in "Add to targets"
6. Click **Add**

## Step 4: Configure Info.plist for Each Extension

### ShareExtension:
1. Select ShareExtension target
2. Go to **Build Settings**
3. Search for "Info.plist"
4. Set **Info.plist File** to: `iOS/ShareExtension/Info.plist`

### ActionExtension:
1. Select ActionExtension target
2. Go to **Build Settings**
3. Search for "Info.plist"
4. Set **Info.plist File** to: `iOS/ActionExtension/Info.plist`

## Step 5: Configure App Groups

For **EACH target** (TranslateLocal, ShareExtension, ActionExtension):

1. Select the target
2. Go to **Signing & Capabilities**
3. Click **+ Capability**
4. Select **App Groups**
5. Click **+** under App Groups
6. Add: `group.com.translatelocal.shared`

## Step 6: Set Bundle Identifiers

| Target | Bundle Identifier |
|--------|-------------------|
| TranslateLocal | `oceania1984.InIndiana.AWT.TranslateLocal` |
| ShareExtension | `oceania1984.InIndiana.AWT.TranslateLocal.ShareExtension` |
| ActionExtension | `oceania1984.InIndiana.AWT.TranslateLocal.ActionExtension` |

## Step 7: Configure Entitlements

For **EACH target**, set the entitlements file in Build Settings:

1. Select target
2. **Build Settings** → Search "Entitlements"
3. Set **Code Signing Entitlements**:
   - TranslateLocal: `TranslateLocal/TranslateLocal.entitlements`
   - ShareExtension: `iOS/ShareExtension/ShareExtension.entitlements`
   - ActionExtension: `iOS/ActionExtension/ActionExtension.entitlements`

## Step 8: Remove Duplicate Sources from Main App

1. Select **TranslateLocal** target
2. Go to **Build Phases** → **Compile Sources**
3. Find and **remove** (if present):
   - `ShareViewController.swift`
   - `ActionViewController.swift`
   
These should only be in their respective extension targets.

## Step 9: Verify Extension Embedding

1. Select **TranslateLocal** target
2. Go to **General** tab
3. Scroll to **Frameworks, Libraries, and Embedded Content**
4. Ensure both extensions show as **Embed & Sign** (or they may appear under "Embed App Extensions")

## ✅ Verification

Build the project (⌘B). You should see:
- TranslateLocal.app builds successfully
- ShareExtension.appex is embedded
- ActionExtension.appex is embedded

