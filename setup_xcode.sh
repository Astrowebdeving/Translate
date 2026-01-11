#!/bin/bash

# =============================================================================
# TranslateLocal - Xcode Project Setup Script
# =============================================================================
#
# This script helps you create an Xcode project and set up the development
# environment for TranslateLocal.
#
# Usage:
#   chmod +x setup_xcode.sh
#   ./setup_xcode.sh
#
# =============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print banner
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}       🌐 ${GREEN}TranslateLocal${NC} - Xcode Setup Script              ${BLUE}║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# =============================================================================
# Step 1: Check Prerequisites
# =============================================================================

echo -e "${YELLOW}📋 Step 1: Checking prerequisites...${NC}"

# Check Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode is not installed!${NC}"
    echo "   Please install Xcode from the App Store"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n1 | awk '{print $2}')
echo -e "   ${GREEN}✓${NC} Xcode $XCODE_VERSION installed"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 is not installed!${NC}"
    echo "   Install with: brew install python3"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
echo -e "   ${GREEN}✓${NC} Python $PYTHON_VERSION installed"

# Check xcode-select
if ! xcode-select -p &> /dev/null; then
    echo -e "${YELLOW}⚠️  Xcode Command Line Tools not installed${NC}"
    echo "   Installing..."
    xcode-select --install
    echo "   Please complete the installation and run this script again"
    exit 1
fi
echo -e "   ${GREEN}✓${NC} Xcode Command Line Tools installed"

echo ""

# =============================================================================
# Step 2: Set up Python Environment
# =============================================================================

echo -e "${YELLOW}🐍 Step 2: Setting up Python environment for model conversion...${NC}"

cd "$SCRIPT_DIR/MLModels"

if [ ! -d "venv" ]; then
    echo "   Creating virtual environment..."
    python3 -m venv venv
fi

echo "   Activating virtual environment..."
source venv/bin/activate

echo "   Installing dependencies..."
pip install -q --upgrade pip
pip install -q -r requirements.txt

echo -e "   ${GREEN}✓${NC} Python environment ready"
echo ""

cd "$SCRIPT_DIR"

# =============================================================================
# Step 3: Create Xcode Project Structure
# =============================================================================

echo -e "${YELLOW}📱 Step 3: Preparing Xcode project...${NC}"

# We can't programmatically create .xcodeproj, but we can prepare everything
# and give clear instructions

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Setup Complete! Now follow these manual steps:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}🛠️  STEP A: Create Xcode Project${NC}"
echo ""
echo "   1. Open Xcode"
echo "   2. Click File → New → Project (⌘⇧N)"
echo "   3. Select iOS → App → Next"
echo "   4. Fill in:"
echo "      • Product Name: TranslateLocal"
echo "      • Team: (Your Apple Developer account)"
echo "      • Organization Identifier: com.yourname"
echo "      • Interface: SwiftUI"
echo "      • Language: Swift"
echo "   5. Save to: $SCRIPT_DIR/iOS/"
echo ""
echo -e "${YELLOW}🛠️  STEP B: Add Source Files${NC}"
echo ""
echo "   1. In Xcode, delete the auto-generated ContentView.swift and"
echo "      TranslateLocalApp.swift (move to trash)"
echo "   2. In Finder, open: $SCRIPT_DIR/iOS/TranslateLocal/"
echo "   3. Select all folders (App, Views, Services, Models, ViewModels)"
echo "   4. Drag them into your Xcode project navigator"
echo "   5. When prompted:"
echo "      ☑️ Copy items if needed"
echo "      ☑️ Create groups"
echo "      ☑️ Add to target: TranslateLocal"
echo ""
echo -e "${YELLOW}🛠️  STEP C: Add Extensions (Optional)${NC}"
echo ""
echo "   1. File → New → Target"
echo "   2. Select iOS → Share Extension"
echo "   3. Name: ShareExtension"
echo "   4. Replace generated files with our ShareExtension/ files"
echo "   5. Repeat for ActionExtension"
echo ""
echo -e "${YELLOW}🛠️  STEP D: Configure Capabilities${NC}"
echo ""
echo "   1. Select project in navigator (blue icon)"
echo "   2. Select TranslateLocal target"
echo "   3. Go to Signing & Capabilities"
echo "   4. Click + Capability, add:"
echo "      • App Groups (group.com.translatelocal.shared)"
echo ""
echo -e "${YELLOW}🛠️  STEP E: Convert & Add ML Model${NC}"
echo ""
echo "   Run this in Terminal:"
echo ""
echo "   cd $SCRIPT_DIR/MLModels"
echo "   source venv/bin/activate"
echo "   python convert_opus_to_coreml.py --source en --target ja"
echo ""
echo "   Then drag the .mlpackage file from Resources/Models/ into Xcode"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "📖 For detailed instructions, see: ${GREEN}GETTING_STARTED.md${NC}"
echo -e "🏗️  For architecture details, see: ${GREEN}ARCHITECTURE.md${NC}"
echo ""

# =============================================================================
# Optional: Open relevant files
# =============================================================================

read -p "Would you like to open the documentation? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$SCRIPT_DIR/GETTING_STARTED.md"
    open "$SCRIPT_DIR/ARCHITECTURE.md"
fi

read -p "Would you like to open the iOS source folder in Finder? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$SCRIPT_DIR/iOS/TranslateLocal/"
fi

echo ""
echo -e "${GREEN}🎉 Good luck with your development!${NC}"
echo ""
