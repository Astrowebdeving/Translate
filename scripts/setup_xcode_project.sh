#!/bin/bash

#===============================================================================
# TranslateLocal - Xcode Project Setup Script
#===============================================================================
# This script automates the configuration of the Xcode project including:
# - Extension target creation
# - App Groups configuration
# - Entitlements setup
# - Build settings
#
# Usage: ./scripts/setup_xcode_project.sh
#===============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XCODEPROJ="$PROJECT_ROOT/TranslateLocal.xcodeproj"
PROJECT_FILE="$XCODEPROJ/project.pbxproj"

# Bundle identifiers
MAIN_BUNDLE_ID="oceania1984.InIndiana.AWT.TranslateLocal"
SHARE_BUNDLE_ID="${MAIN_BUNDLE_ID}.ShareExtension"
ACTION_BUNDLE_ID="${MAIN_BUNDLE_ID}.ActionExtension"

# App Group
APP_GROUP="group.com.translatelocal.shared"

#===============================================================================
# Helper Functions
#===============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}➤ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed or not in PATH"
        return 1
    fi
    return 0
}

#===============================================================================
# Validation
#===============================================================================

print_header "TranslateLocal Xcode Setup Script"

print_step "Validating environment..."

# Check we're in the right directory
if [ ! -f "$PROJECT_FILE" ]; then
    print_error "Cannot find Xcode project at: $XCODEPROJ"
    print_error "Please run this script from the project root directory"
    exit 1
fi

print_success "Found Xcode project"

# Check for Ruby (comes with macOS)
if check_command ruby; then
    print_success "Ruby is available"
else
    print_error "Ruby is required but not found"
    exit 1
fi

# Check for PlistBuddy
PLIST_BUDDY="/usr/libexec/PlistBuddy"
if [ -f "$PLIST_BUDDY" ]; then
    print_success "PlistBuddy is available"
else
    print_error "PlistBuddy not found at $PLIST_BUDDY"
    exit 1
fi

#===============================================================================
# Create Directory Structure
#===============================================================================

print_header "Setting Up Directory Structure"

# Ensure scripts directory exists
mkdir -p "$PROJECT_ROOT/scripts"

# Ensure extension directories exist
mkdir -p "$PROJECT_ROOT/iOS/ShareExtension"
mkdir -p "$PROJECT_ROOT/iOS/ActionExtension"

print_success "Directory structure verified"

#===============================================================================
# Create/Update Entitlements Files
#===============================================================================

print_header "Configuring Entitlements"

create_entitlements() {
    local filepath="$1"
    local dirname=$(dirname "$filepath")
    
    mkdir -p "$dirname"
    
    cat > "$filepath" << 'ENTITLEMENTS_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.translatelocal.shared</string>
    </array>
</dict>
</plist>
ENTITLEMENTS_EOF
    
    print_success "Created entitlements: $filepath"
}

# Main app entitlements
create_entitlements "$PROJECT_ROOT/TranslateLocal/TranslateLocal.entitlements"

# Share Extension entitlements
create_entitlements "$PROJECT_ROOT/iOS/ShareExtension/ShareExtension.entitlements"

# Action Extension entitlements
create_entitlements "$PROJECT_ROOT/iOS/ActionExtension/ActionExtension.entitlements"

#===============================================================================
# Update Info.plist Files
#===============================================================================

print_header "Updating Info.plist Files"

# Main App Info.plist - ensure camera/photo permissions
MAIN_INFO_PLIST="$PROJECT_ROOT/iOS/TranslateLocal/Resources/Info.plist"
if [ -f "$MAIN_INFO_PLIST" ]; then
    print_step "Updating main app Info.plist..."
    
    # Add camera usage description if not present
    if ! $PLIST_BUDDY -c "Print :NSCameraUsageDescription" "$MAIN_INFO_PLIST" &>/dev/null; then
        $PLIST_BUDDY -c "Add :NSCameraUsageDescription string 'TranslateLocal needs camera access to recognize and translate text in real-time. All processing happens on your device.'" "$MAIN_INFO_PLIST" 2>/dev/null || true
    fi
    
    # Add photo library usage description if not present
    if ! $PLIST_BUDDY -c "Print :NSPhotoLibraryUsageDescription" "$MAIN_INFO_PLIST" &>/dev/null; then
        $PLIST_BUDDY -c "Add :NSPhotoLibraryUsageDescription string 'TranslateLocal needs photo library access to translate text from your images.'" "$MAIN_INFO_PLIST" 2>/dev/null || true
    fi
    
    print_success "Main app Info.plist updated"
fi

# Share Extension Info.plist
SHARE_INFO_PLIST="$PROJECT_ROOT/iOS/ShareExtension/Info.plist"
print_step "Creating Share Extension Info.plist..."
cat > "$SHARE_INFO_PLIST" << 'SHARE_PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Translate</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsImageWithMaxCount</key>
                <integer>10</integer>
                <key>NSExtensionActivationSupportsText</key>
                <true/>
            </dict>
        </dict>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
    </dict>
</dict>
</plist>
SHARE_PLIST_EOF
print_success "Share Extension Info.plist created"

# Action Extension Info.plist
ACTION_INFO_PLIST="$PROJECT_ROOT/iOS/ActionExtension/Info.plist"
print_step "Creating Action Extension Info.plist..."
cat > "$ACTION_INFO_PLIST" << 'ACTION_PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Translate</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>NSExtensionActivationRule</key>
            <dict>
                <key>NSExtensionActivationSupportsText</key>
                <true/>
            </dict>
        </dict>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).ActionViewController</string>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.ui-services</string>
    </dict>
</dict>
</plist>
ACTION_PLIST_EOF
print_success "Action Extension Info.plist created"

#===============================================================================
# Generate XcodeGen Specification (Optional Modern Approach)
#===============================================================================

print_header "Creating Project Specification"

# Create an XcodeGen project.yml if xcodegen is available
XCODEGEN_SPEC="$PROJECT_ROOT/project.yml"

cat > "$XCODEGEN_SPEC" << XCODEGEN_EOF
name: TranslateLocal
options:
  bundleIdPrefix: oceania1984.InIndiana.AWT
  deploymentTarget:
    iOS: "17.0"
  xcodeVersion: "15.0"
  minimumXcodeGenVersion: "2.35.0"

settings:
  base:
    IPHONEOS_DEPLOYMENT_TARGET: "26.2"
    SWIFT_VERSION: "5.0"
    DEVELOPMENT_TEAM: ""  # Add your team ID here

targets:
  TranslateLocal:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: iOS/TranslateLocal
        excludes:
          - "**/.DS_Store"
      - path: TranslateLocal
        excludes:
          - "**/.DS_Store"
    resources:
      - path: Resources
        excludes:
          - "**/.DS_Store"
    settings:
      base:
        INFOPLIST_FILE: iOS/TranslateLocal/Resources/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: oceania1984.InIndiana.AWT.TranslateLocal
        CODE_SIGN_ENTITLEMENTS: TranslateLocal/TranslateLocal.entitlements
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    entitlements:
      path: TranslateLocal/TranslateLocal.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.translatelocal.shared

  ShareExtension:
    type: app-extension
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: iOS/ShareExtension
        excludes:
          - "**/.DS_Store"
          - Info.plist
    settings:
      base:
        INFOPLIST_FILE: iOS/ShareExtension/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: oceania1984.InIndiana.AWT.TranslateLocal.ShareExtension
        CODE_SIGN_ENTITLEMENTS: iOS/ShareExtension/ShareExtension.entitlements
        SKIP_INSTALL: YES
    entitlements:
      path: iOS/ShareExtension/ShareExtension.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.translatelocal.shared
    dependencies:
      - target: TranslateLocal
        embed: false

  ActionExtension:
    type: app-extension
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: iOS/ActionExtension
        excludes:
          - "**/.DS_Store"
          - Info.plist
    settings:
      base:
        INFOPLIST_FILE: iOS/ActionExtension/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: oceania1984.InIndiana.AWT.TranslateLocal.ActionExtension
        CODE_SIGN_ENTITLEMENTS: iOS/ActionExtension/ActionExtension.entitlements
        SKIP_INSTALL: YES
    entitlements:
      path: iOS/ActionExtension/ActionExtension.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.translatelocal.shared
    dependencies:
      - target: TranslateLocal
        embed: false

schemes:
  TranslateLocal:
    build:
      targets:
        TranslateLocal: all
        ShareExtension: all
        ActionExtension: all
    run:
      config: Debug
    test:
      config: Debug
    profile:
      config: Release
    analyze:
      config: Debug
    archive:
      config: Release
XCODEGEN_EOF

print_success "Created XcodeGen specification at project.yml"

#===============================================================================
# Check for XcodeGen and offer to generate project
#===============================================================================

print_header "Project Generation Options"

if check_command xcodegen 2>/dev/null; then
    print_success "XcodeGen is installed!"
    echo ""
    read -p "Do you want to regenerate the Xcode project using XcodeGen? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_step "Backing up existing project..."
        if [ -d "$XCODEPROJ" ]; then
            cp -r "$XCODEPROJ" "${XCODEPROJ}.backup.$(date +%Y%m%d_%H%M%S)"
            print_success "Backup created"
        fi
        
        print_step "Generating Xcode project..."
        cd "$PROJECT_ROOT"
        xcodegen generate
        print_success "Xcode project regenerated!"
    fi
else
    print_warning "XcodeGen not installed. You can install it with: brew install xcodegen"
    echo ""
    echo "To use XcodeGen (recommended for clean project setup):"
    echo "  1. Install: brew install xcodegen"
    echo "  2. Run: xcodegen generate"
    echo ""
    echo "Or manually configure extensions in Xcode (see instructions below)."
fi

#===============================================================================
# Create Manual Setup Instructions
#===============================================================================

INSTRUCTIONS_FILE="$PROJECT_ROOT/XCODE_SETUP_INSTRUCTIONS.md"

cat > "$INSTRUCTIONS_FILE" << 'INSTRUCTIONS_EOF'
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

INSTRUCTIONS_EOF

print_success "Created manual instructions at XCODE_SETUP_INSTRUCTIONS.md"

#===============================================================================
# Summary
#===============================================================================

print_header "Setup Complete!"

echo -e "${GREEN}The following files have been created/updated:${NC}"
echo ""
echo "  📁 Entitlements:"
echo "     • TranslateLocal/TranslateLocal.entitlements"
echo "     • iOS/ShareExtension/ShareExtension.entitlements"
echo "     • iOS/ActionExtension/ActionExtension.entitlements"
echo ""
echo "  📁 Info.plist files:"
echo "     • iOS/ShareExtension/Info.plist"
echo "     • iOS/ActionExtension/Info.plist"
echo ""
echo "  📁 Configuration:"
echo "     • project.yml (XcodeGen specification)"
echo "     • XCODE_SETUP_INSTRUCTIONS.md"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "  Option A (Recommended - if XcodeGen installed):"
echo "     brew install xcodegen"
echo "     cd $PROJECT_ROOT"
echo "     xcodegen generate"
echo ""
echo "  Option B (Manual):"
echo "     Open XCODE_SETUP_INSTRUCTIONS.md and follow the steps"
echo ""
echo "  Then:"
echo "     1. Open TranslateLocal.xcodeproj in Xcode"
echo "     2. Select your development team in Signing & Capabilities"
echo "     3. Build and run (⌘R)"
echo ""
print_success "Done! 🎉"
