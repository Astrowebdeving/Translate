#!/bin/bash
# =============================================================================
# 🌍 TranslateLocal - Download All Opus-MT Models
# =============================================================================
# This script downloads all supported language pair models from HuggingFace.
# Run this first, then use convert_all_models.sh to convert them.
#
# Usage: ./download_all_models.sh
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAW_MODELS_DIR="${SCRIPT_DIR}/raw_models"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🌍 TranslateLocal - Model Downloader${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

mkdir -p "$RAW_MODELS_DIR"

# Function to download a model
download_model() {
    local LOCAL_NAME=$1
    local HF_MODEL=$2
    
    if [ -d "${RAW_MODELS_DIR}/${LOCAL_NAME}" ]; then
        echo -e "${YELLOW}⏭️  Skipping ${LOCAL_NAME} (already exists)${NC}"
        return 0
    fi
    
    echo -e "${BLUE}📥 Downloading ${LOCAL_NAME} from ${HF_MODEL}...${NC}"
    huggingface-cli download "${HF_MODEL}" --local-dir "${RAW_MODELS_DIR}/${LOCAL_NAME}"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ ${LOCAL_NAME} downloaded successfully${NC}"
    else
        echo -e "${RED}❌ Failed to download ${LOCAL_NAME}${NC}"
        return 1
    fi
}

echo ""
echo -e "${BLUE}📦 Downloading Opus-MT Models...${NC}"
echo ""

# Chinese ↔ English
download_model "zh-en" "Helsinki-NLP/opus-mt-zh-en"
download_model "en-zh" "Helsinki-NLP/opus-mt-en-zh"

# Japanese ↔ English (note: uses "jap" not "ja" for general)
download_model "en-ja" "Helsinki-NLP/opus-mt-en-jap"
# Note: ja-en uses a different model (FuguMT) as Helsinki's jap-en may not exist
download_model "ja-en" "Mitsua/elan-mt-bt-ja-en" || echo -e "${YELLOW}⚠️  ja-en alternative model used${NC}"

# Spanish ↔ English
download_model "es-en" "Helsinki-NLP/opus-mt-es-en"
download_model "en-es" "Helsinki-NLP/opus-mt-en-es"

# Korean ↔ English - SKIPPED (only tc-big models exist, different architecture)
# download_model "ko-en" "Helsinki-NLP/opus-mt-tc-big-ko-en"
# download_model "en-ko" "Helsinki-NLP/opus-mt-tc-big-en-ko"
echo -e "${YELLOW}⏭️  Skipping Korean (ko-en, en-ko) - only tc-big models exist (different architecture)${NC}"

# German ↔ English
download_model "de-en" "Helsinki-NLP/opus-mt-de-en"
download_model "en-de" "Helsinki-NLP/opus-mt-en-de"

# French ↔ English  
download_model "fr-en" "Helsinki-NLP/opus-mt-fr-en"
download_model "en-fr" "Helsinki-NLP/opus-mt-en-fr"

# Russian ↔ English
download_model "ru-en" "Helsinki-NLP/opus-mt-ru-en"
download_model "en-ru" "Helsinki-NLP/opus-mt-en-ru"

# Hindi ↔ English
download_model "hi-en" "Helsinki-NLP/opus-mt-hi-en"
download_model "en-hi" "Helsinki-NLP/opus-mt-en-hi"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📥 Downloading Gemma 3n E2B (requires HuggingFace login)...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}⚠️  Gemma requires accepting Google's license on HuggingFace first!${NC}"
echo -e "${YELLOW}   1. Go to: https://huggingface.co/google/gemma-3n-E2B-it${NC}"
echo -e "${YELLOW}   2. Click 'Agree and access repository'${NC}"
echo -e "${YELLOW}   3. Run: huggingface-cli login${NC}"
echo ""

download_model "gemma-3n-e2b" "google/gemma-3n-E2B-it" || echo -e "${YELLOW}⚠️  Gemma download may require login - see instructions above${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ All downloads complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next step: Run ./convert_all_models.sh --repo your-username/your-repo"
echo ""
