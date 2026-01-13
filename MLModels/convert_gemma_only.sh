#!/bin/bash
# =============================================================================
# 🤖 TranslateLocal - Convert Gemma 3n E2B Only
# =============================================================================
# This script converts only the Gemma 3n E2B model to CoreML format.
#
# Usage: ./convert_gemma_only.sh --repo your-username/your-repo
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_MODELS_DIR="${SCRIPT_DIR}/raw_models"
VENV_DIR="${SCRIPT_DIR}/venv"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Parse arguments
REPO_ID=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --repo) REPO_ID="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$REPO_ID" ]; then
    echo -e "${YELLOW}⚠️  No --repo specified. Will convert but skip packaging.${NC}"
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🤖 TranslateLocal - Gemma 3n E2B Converter${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if Gemma is downloaded
if [ ! -d "${RAW_MODELS_DIR}/gemma-3n-e2b" ]; then
    echo -e "${YELLOW}⚠️  Gemma not found in raw_models/gemma-3n-e2b${NC}"
    echo ""
    echo "To download Gemma:"
    echo "1. Accept license at: https://huggingface.co/google/gemma-3n-E2B-it"
    echo "2. Run: huggingface-cli login"
    echo "3. Run: huggingface-cli download google/gemma-3n-E2B-it --local-dir ./raw_models/gemma-3n-e2b"
    echo ""
    exit 1
fi

# Activate virtual environment
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${BLUE}📦 Creating virtual environment...${NC}"
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install -q -r "$SCRIPT_DIR/requirements.txt"

echo ""
echo -e "${BLUE}🔄 Converting Gemma 3n E2B to CoreML...${NC}"
echo -e "${YELLOW}⚠️  This may take 10-30 minutes and requires ~16GB RAM${NC}"
echo ""

# Run the conversion
python3 "$SCRIPT_DIR/convert_gemma_to_coreml.py" \
    --model-name "${RAW_MODELS_DIR}/gemma-3n-e2b" \
    --output-dir "${SCRIPT_DIR}/../Resources/Models" \
    --quantize float16 \
    --max-length 512

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Gemma converted to CoreML successfully!${NC}"
    
    # Package for distribution if repo specified
    if [ -n "$REPO_ID" ]; then
        echo ""
        echo -e "${BLUE}📦 Packaging for distribution...${NC}"
        "$SCRIPT_DIR/prepare_for_distribution.sh" --gemma --repo "$REPO_ID"
    fi
else
    echo -e "${RED}❌ Gemma conversion failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Done!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
