#!/bin/bash
# Convert Korean → English Opus-MT model to CoreML and upload to HuggingFace
# Uses the standard Helsinki-NLP/opus-mt-ko-en model (NOT tc-big)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🇰🇷 Korean → English Model Conversion Script${NC}"
echo "=============================================="
echo ""

# Check for virtual environment
if [ ! -d "venv" ]; then
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv venv
fi

source venv/bin/activate

# Install requirements
echo -e "${YELLOW}Installing requirements...${NC}"
pip install -q transformers torch coremltools sentencepiece

# Create raw_models directory
mkdir -p raw_models

# Download Korean → English model
MODEL_ID="ko-en"
HF_MODEL="Helsinki-NLP/opus-mt-ko-en"

echo ""
echo -e "${YELLOW}📥 Downloading ${HF_MODEL}...${NC}"

if [ ! -d "raw_models/${MODEL_ID}" ]; then
    huggingface-cli download ${HF_MODEL} --local-dir ./raw_models/${MODEL_ID}
    echo -e "${GREEN}✅ Downloaded ${MODEL_ID} model${NC}"
else
    echo -e "${GREEN}✅ Model already exists at raw_models/${MODEL_ID}${NC}"
fi

# Convert to CoreML using the existing conversion script
echo ""
echo -e "${YELLOW}🔄 Converting to CoreML...${NC}"

python3 convert_opus_to_coreml.py --model ${MODEL_ID} --output ../Resources/Models

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Conversion failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Conversion complete!${NC}"

# Prepare for distribution
echo ""
echo -e "${YELLOW}📦 Preparing for distribution...${NC}"

./prepare_for_distribution.sh --model ${MODEL_ID} --repo tu101/models_MLconverted

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Distribution preparation failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}=============================================="
echo "✅ Korean → English model ready!"
echo "=============================================="
echo ""
echo "Files created:"
echo "  - dist/OpusMT_ko_en.zip"
echo "  - dist/registry.json (updated)"
echo ""
echo -e "${BLUE}To upload to HuggingFace:${NC}"
echo ""
echo "  huggingface-cli login"
echo "  huggingface-cli upload tu101/models_MLconverted dist/OpusMT_ko_en.zip OpusMT_ko_en.zip --repo-type dataset"
echo "  huggingface-cli upload tu101/models_MLconverted dist/registry.json registry.json --repo-type dataset"
echo ""
echo -e "${NC}"
