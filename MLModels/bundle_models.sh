#!/bin/bash
# =============================================================================
# Model Bundling Script for TranslateLocal
# =============================================================================
# This script converts and bundles ML models for the iOS app
# 
# Usage:
#   ./bundle_models.sh              # Convert default models (Spanish ↔ English)
#   ./bundle_models.sh --all        # Convert all supported models
#   ./bundle_models.sh en-es es-en  # Convert specific models
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/../Resources/Models"
VENV_DIR="${SCRIPT_DIR}/venv"

echo "🧠 TranslateLocal Model Bundling Script"
echo "======================================="
echo ""

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not found!"
    echo "   Install it from https://www.python.org/"
    exit 1
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "📦 Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate virtual environment
echo "🔧 Activating virtual environment..."
source "$VENV_DIR/bin/activate"

# Install dependencies
echo "📥 Installing dependencies..."
pip install --quiet --upgrade pip
pip install --quiet -r "$SCRIPT_DIR/requirements.txt"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo ""
echo "🚀 Starting model conversion..."
echo "   Output directory: $OUTPUT_DIR"
echo ""

# Parse arguments
if [ "$1" == "--all" ]; then
    # Convert all default models
    MODELS="en-es es-en"
    echo "📋 Converting default models: $MODELS"
elif [ $# -gt 0 ]; then
    # Convert specified models
    MODELS="$@"
    echo "📋 Converting specified models: $MODELS"
else
    # Default: Spanish ↔ English only
    MODELS="en-es es-en"
    echo "📋 Converting default models: $MODELS"
fi

# Convert each model
for MODEL in $MODELS; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Converting: $MODEL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    python3 "$SCRIPT_DIR/convert_opus_to_coreml.py" \
        --model "$MODEL" \
        --output "$OUTPUT_DIR" \
        --quantize float16
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Model conversion complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Models saved to: $OUTPUT_DIR"
echo ""
echo "📋 Next steps:"
echo "   1. Open TranslateLocal.xcodeproj in Xcode"
echo "   2. Right-click 'Resources' group → 'Add Files'"
echo "   3. Select the .mlpackage folders from Resources/Models/"
echo "   4. Ensure 'Copy items if needed' is checked"
echo "   5. Ensure 'Add to targets: TranslateLocal' is checked"
echo "   6. Build and run!"
echo ""

# Deactivate virtual environment
deactivate

echo "🎉 Done!"
