#!/bin/bash
# =============================================================================
# 🔄 TranslateLocal - Convert All Models to CoreML
# =============================================================================
# This script converts all downloaded models to CoreML format and packages them.
# Run download_all_models.sh first!
#
# Usage: ./convert_all_models.sh --repo your-username/your-repo
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
    echo -e "${RED}❌ Error: Please specify --repo (e.g., --repo username/repo-name)${NC}"
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔄 TranslateLocal - Model Converter & Packager${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Activate virtual environment
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${BLUE}📦 Creating virtual environment...${NC}"
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install -q -r "$SCRIPT_DIR/requirements.txt"

# List of models to convert (must match folder names in raw_models/)
# Note: Korean (ko-en, en-ko) excluded - only tc-big models exist which use different architecture
OPUS_MODELS=(
    "zh-en"
    "en-zh"
    "en-ja"
    "es-en"
    "en-es"
    "de-en"
    "en-de"
    "fr-en"
    "en-fr"
    "ru-en"
    "en-ru"
    "hi-en"
    "en-hi"
)

# Track results
SUCCESS_MODELS=()
FAILED_MODELS=()

echo ""
echo -e "${BLUE}🔄 Converting Opus-MT Models...${NC}"
echo ""

for MODEL in "${OPUS_MODELS[@]}"; do
    if [ ! -d "${RAW_MODELS_DIR}/${MODEL}" ]; then
        echo -e "${YELLOW}⏭️  Skipping ${MODEL} (not downloaded)${NC}"
        continue
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔄 Converting: ${MODEL}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Step 1: Convert to CoreML
    if python3 "$SCRIPT_DIR/convert_opus_to_coreml.py" --model "$MODEL" --output "${SCRIPT_DIR}/../Resources/Models"; then
        echo -e "${GREEN}✅ ${MODEL} converted to CoreML${NC}"
        
        # Step 2: Package for distribution
        if "$SCRIPT_DIR/prepare_for_distribution.sh" --model "$MODEL" --repo "$REPO_ID"; then
            echo -e "${GREEN}✅ ${MODEL} packaged for distribution${NC}"
            SUCCESS_MODELS+=("$MODEL")
        else
            echo -e "${RED}❌ ${MODEL} packaging failed${NC}"
            FAILED_MODELS+=("$MODEL (packaging)")
        fi
    else
        echo -e "${RED}❌ ${MODEL} conversion failed${NC}"
        FAILED_MODELS+=("$MODEL (conversion)")
    fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ ${#SUCCESS_MODELS[@]} -gt 0 ]; then
    echo -e "${GREEN}✅ Successfully converted: ${SUCCESS_MODELS[*]}${NC}"
fi

if [ ${#FAILED_MODELS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Failed: ${FAILED_MODELS[*]}${NC}"
fi

# Convert Gemma 3n E2B if downloaded
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔄 Converting Gemma 3n E2B (if available)...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -d "${RAW_MODELS_DIR}/gemma-3n-e2b" ]; then
    echo -e "${BLUE}🔄 Converting Gemma 3n E2B...${NC}"
    if python3 "$SCRIPT_DIR/convert_gemma_to_coreml.py" --output-dir "${SCRIPT_DIR}/../Resources/Models"; then
        echo -e "${GREEN}✅ Gemma converted to CoreML${NC}"
        
        if "$SCRIPT_DIR/prepare_for_distribution.sh" --gemma --repo "$REPO_ID"; then
            echo -e "${GREEN}✅ Gemma packaged for distribution${NC}"
            SUCCESS_MODELS+=("gemma-3n-e2b")
        else
            echo -e "${RED}❌ Gemma packaging failed${NC}"
            FAILED_MODELS+=("gemma-3n-e2b (packaging)")
        fi
    else
        echo -e "${RED}❌ Gemma conversion failed${NC}"
        FAILED_MODELS+=("gemma-3n-e2b (conversion)")
    fi
else
    echo -e "${YELLOW}⏭️  Skipping Gemma (not downloaded - requires HuggingFace login)${NC}"
fi

echo ""
echo -e "${BLUE}📁 Packaged models are in: ${SCRIPT_DIR}/dist/${NC}"
echo ""
echo "Next steps:"
echo "1. Upload to HuggingFace: python3 hf_upload.py --repo $REPO_ID --folder dist"
echo "2. Update iOS app: Set huggingFaceRepo = \"$REPO_ID\" in CoreMLModelDownloader.swift"
echo ""
