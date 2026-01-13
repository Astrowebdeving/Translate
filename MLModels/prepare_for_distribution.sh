#!/bin/bash
# =============================================================================
# 🚀 TranslateLocal - Model Distribution Preparer
# =============================================================================
# This script prepares converted CoreML models for distribution/download.
# It compiles .mlpackage to .mlmodelc and zips them with configs.
#
# Usage:
#   ./prepare_for_distribution.sh --model en-es --repo username/repo
#   ./prepare_for_distribution.sh --gemma --repo username/repo
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIST_DIR="${SCRIPT_DIR}/dist"
TEMP_DIR="${SCRIPT_DIR}/temp_compile"
RESOURCE_MODELS_DIR="${SCRIPT_DIR}/../Resources/Models"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧠 Preparing Models for iOS Distribution...${NC}"

# 1. Parse Arguments
MODEL_ID=""
IS_GEMMA=false
REPO_ID=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --model) MODEL_ID="$2"; shift ;;
        --gemma) IS_GEMMA=true ;;
        --repo) REPO_ID="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

if [ "$IS_GEMMA" = false ] && [ -z "$MODEL_ID" ]; then
    echo "❌ Error: Please specify a model ID (e.g., --model en-es) or --gemma"
    exit 1
fi

if [ -z "$REPO_ID" ]; then
    echo "⚠️ Warning: No --repo specified. Download URLs in registry.json will need manual update."
    BASE_URL="REPLACE_WITH_HF_URL"
else
    BASE_URL="https://huggingface.co/datasets/${REPO_ID}/resolve/main"
fi

# 2. Set file paths based on model type
if [ "$IS_GEMMA" = true ]; then
    MODEL_TYPE="gemma"
    FINAL_NAME="Gemma3nE2B"
    PACKAGE_ENCODER="${RESOURCE_MODELS_DIR}/Gemma3nE2B.mlpackage"
    COMPONENTS=("$PACKAGE_ENCODER")
    ID="gemma-3n-multilingual"
    NAME="Gemma 3n Multilingual"
    DESC="Google's Gemma 3n model - supports any language pair with context understanding"
    SRC="*"
    TGT="*"
else
    MODEL_TYPE="opus"
    FINAL_NAME="OpusMT_${MODEL_ID//-/_}"
    PACKAGE_ENCODER="${RESOURCE_MODELS_DIR}/${FINAL_NAME}_encoder.mlpackage"
    PACKAGE_DECODER="${RESOURCE_MODELS_DIR}/${FINAL_NAME}_decoder.mlpackage"
    CONFIG_JSON="${RESOURCE_MODELS_DIR}/${FINAL_NAME}_config.json"
    VOCAB_JSON="${RESOURCE_MODELS_DIR}/${FINAL_NAME}_vocab.json"
    COMPONENTS=("$PACKAGE_ENCODER" "$PACKAGE_DECODER")
    ID="opus-$MODEL_ID"
    NAME="Opus-MT $MODEL_ID"
    DESC="Helsinki-NLP Opus-MT model for $MODEL_ID translation"
    SRC="${MODEL_ID%%-*}"
    TGT="${MODEL_ID#*-}"
fi

# 3. Verify files exist
for COMP in "${COMPONENTS[@]}"; do
    if [ ! -d "$COMP" ]; then
        echo "❌ Error: Converted .mlpackage not found at $COMP"
        if [ "$IS_GEMMA" = true ]; then
            echo "   Run python3 convert_gemma_to_coreml.py first."
        else
            echo "   Run ./bundle_models.sh $MODEL_ID first."
        fi
        exit 1
    fi
done

# 4. Create Directories
mkdir -p "$DIST_DIR"
mkdir -p "$TEMP_DIR"

# 5. Compile for iOS
echo -e "${BLUE}🔄 Compiling .mlpackage(s) to .mlmodelc...${NC}"

for COMP in "${COMPONENTS[@]}"; do
    echo "   Compiling $(basename "$COMP")..."
    xcrun coremlcompiler compile "$COMP" "$TEMP_DIR"
done

# 6. Package for Distribution
ARCHIVE_PATH="${DIST_DIR}/${FINAL_NAME}.zip"
PACKAGE_FOLDER="${TEMP_DIR}/${FINAL_NAME}"
mkdir -p "$PACKAGE_FOLDER"

echo -e "${BLUE}📦 Zipping compiled models and configs...${NC}"

# Move compiled models
mv "${TEMP_DIR}"/*.mlmodelc "$PACKAGE_FOLDER/"

# Copy configs if they exist
if [ "$IS_GEMMA" = false ]; then
    if [ -f "$CONFIG_JSON" ]; then cp "$CONFIG_JSON" "$PACKAGE_FOLDER/config.json"; fi
    if [ -f "$VOCAB_JSON" ]; then cp "$VOCAB_JSON" "$PACKAGE_FOLDER/vocab.json"; fi
fi

# Create the final zip
cd "$TEMP_DIR"
zip -r -q "$ARCHIVE_PATH" "$FINAL_NAME"
cd "$SCRIPT_DIR"

# 7. Update Registry
SIZE_BYTES=$(stat -f%z "$ARCHIVE_PATH")
METADATA=$(cat <<EOF
{
  "id": "$ID",
  "name": "$NAME",
  "description": "$DESC",
  "downloadURL": "${BASE_URL}/${FINAL_NAME}.zip",
  "sizeBytes": $SIZE_BYTES,
  "version": "1.0.0",
  "sourceLanguage": "$SRC",
  "targetLanguage": "$TGT",
  "modelType": "$MODEL_TYPE"
}
EOF
)

python3 "$SCRIPT_DIR/update_registry.py" "$METADATA"

# 8. Cleanup
rm -rf "$TEMP_DIR"

SIZE_MB=$(echo "scale=2; $SIZE_BYTES / 1024 / 1024" | bc)

echo -e "${GREEN}✅ Done!${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
echo -e "Archive: ${GREEN}${ARCHIVE_PATH}${NC}"
echo -e "Size:    ${GREEN}${SIZE_MB} MB${NC}"
echo -e "ID:      ${GREEN}${ID}${NC}"
echo -e "${BLUE}--------------------------------------------------${NC}"
echo ""
