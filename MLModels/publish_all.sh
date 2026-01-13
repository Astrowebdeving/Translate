#!/bin/bash
# =============================================================================
# 🚀 TranslateLocal - Master Publish Script
# =============================================================================
# This script converts, packages, and prepares all models for distribution.
#
# Usage:
#   ./publish_all.sh --repo username/repo-name
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/venv"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🌟 TranslateLocal - One-Click Model Publisher${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. Parse Arguments
REPO_ID=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --repo) REPO_ID="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$REPO_ID" ]; then
    echo -e "${YELLOW}⚠️  No --repo specified. Where should users download models from?${NC}"
    echo -e "Usage: ./publish_all.sh --repo your-username/your-repo-name"
    exit 1
fi

# 2. Setup environment
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${BLUE}📦 Creating virtual environment...${NC}"
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install -q -r "$SCRIPT_DIR/requirements.txt"

# 3. Convert and Package Gemma (Multilingual)
echo -e "\n${BLUE}🤖 Processing Gemma 3n E2B (Multilingual)...${NC}"
python3 "$SCRIPT_DIR/convert_gemma_to_coreml.py" --output-dir "${SCRIPT_DIR}/../Resources/Models"
./prepare_for_distribution.sh --gemma --repo "$REPO_ID"

# 4. Convert and Package common Opus-MT pairs
COMMON_MODELS="en-es es-en en-zh zh-en en-ja ja-en en-fr fr-en en-de de-en"
echo -e "\n${BLUE}📚 Processing Opus-MT models: $COMMON_MODELS...${NC}"

for MODEL in $COMMON_MODELS; do
    echo -e "${BLUE}🔄 Converting $MODEL...${NC}"
    python3 "$SCRIPT_DIR/convert_opus_to_coreml.py" --model "$MODEL" --output "${SCRIPT_DIR}/../Resources/Models"
    ./prepare_for_distribution.sh --model "$MODEL" --repo "$REPO_ID"
done

echo -e "\n${GREEN}✅ All models converted and packaged in 'dist/' folder!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Next steps to make these 'One-Click' accessible to users:"
echo ""
echo -e "1. ${YELLOW}Upload to Hugging Face:${NC}"
echo -e "   python3 hf_upload.py --repo $REPO_ID"
echo ""
echo -e "2. ${YELLOW}Update iOS App:${NC}"
echo -e "   In CoreMLModelDownloader.swift, set:"
echo -e "   private let huggingFaceRepo = \"$REPO_ID\""
echo ""
echo -e "3. ${YELLOW}Push iOS Changes:${NC}"
echo -e "   Rebuild and distribute your app. Users will see all models"
echo -e "   in the 'Download Models' section!"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
