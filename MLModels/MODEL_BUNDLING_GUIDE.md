# 🧠 Model Bundling Guide

This guide explains how to convert and bundle ML models for TranslateLocal.

## Quick Start - Bundle Spanish ↔ English

### Step 1: Set Up Python Environment

```bash
cd MLModels
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Step 2: Convert Models

```bash
# Convert Spanish ↔ English models (default bundle)
python convert_opus_to_coreml.py --all --output ./converted_models

# Or convert specific models:
python convert_opus_to_coreml.py --model en-es --output ./converted_models
python convert_opus_to_coreml.py --model es-en --output ./converted_models
```

### Step 3: Add to Xcode Project

1. Create folder: `Resources/Models/` in Xcode
2. Drag the `.mlpackage` files from `converted_models/` into Xcode
3. Ensure "Copy items if needed" is checked
4. Ensure "Add to targets: TranslateLocal" is checked

### Step 4: Compile Models (Optional but Recommended)

For faster app launch, pre-compile models:

```bash
xcrun coremlcompiler compile OpusMT_en_es_encoder.mlpackage Resources/Models/
xcrun coremlcompiler compile OpusMT_en_es_decoder.mlpackage Resources/Models/
```

This creates `.mlmodelc` folders that load faster.

---

## Available Models

### Opus-MT Models (~150MB each)

| Language Pair | Model ID | HuggingFace Source |
|--------------|----------|-------------------|
| English → Spanish | `en-es` | Helsinki-NLP/opus-mt-en-es |
| Spanish → English | `es-en` | Helsinki-NLP/opus-mt-es-en |
| English → Japanese | `en-ja` | Helsinki-NLP/opus-mt-en-jap |
| Japanese → English | `ja-en` | Helsinki-NLP/opus-mt-jap-en |
| English → Chinese | `en-zh` | Helsinki-NLP/opus-mt-en-zh |
| Chinese → English | `zh-en` | Helsinki-NLP/opus-mt-zh-en |
| English → French | `en-fr` | Helsinki-NLP/opus-mt-en-fr |
| French → English | `fr-en` | Helsinki-NLP/opus-mt-fr-en |
| English → German | `en-de` | Helsinki-NLP/opus-mt-en-de |
| German → English | `de-en` | Helsinki-NLP/opus-mt-de-en |

### Gemma 3n (~800MB)

The multilingual Gemma model requires a different conversion process:

```bash
python convert_gemma_to_coreml.py --output ./converted_models
```

---

## Model Size Estimates

| Model Type | Size (Float16) | Size (Int8) |
|-----------|----------------|-------------|
| Opus-MT (per pair) | ~150 MB | ~75 MB |
| Gemma 3n E2B | ~800 MB | ~400 MB |

**Recommended Bundle:**
- For minimal app size: Just Spanish ↔ English (~300 MB)
- For common use: Add Japanese, Chinese ↔ English (~900 MB)
- Full bundle: All models (~3 GB - use on-demand downloads instead)

---

## Project Structure After Bundling

```
TranslateLocal/
├── Resources/
│   └── Models/
│       ├── OpusMT_en_es_encoder.mlmodelc/
│       ├── OpusMT_en_es_decoder.mlmodelc/
│       ├── OpusMT_es_en_encoder.mlmodelc/
│       ├── OpusMT_es_en_decoder.mlmodelc/
│       ├── OpusMT_en_es_config.json
│       ├── OpusMT_en_es_vocab.json
│       └── ...
```

---

## Updating ModelManager for Bundled Models

Once you've added models, update `ModelManager.swift` to recognize them:

```swift
// In scanAvailableModels()
// The existing code already scans for .mlmodelc and .mlpackage files
// Just make sure the file names match the TranslationModelType raw values
```

The model files should be named to match `TranslationModelType.rawValue`:
- `OpusMT_en_es.mlmodelc` (matches `.opusEnEs`)
- `OpusMT_es_en.mlmodelc` (matches `.opusEsEn`)

---

## Troubleshooting

### "Model not found" error
- Check that .mlmodelc files are in the app bundle (Build Phases → Copy Bundle Resources)
- Verify file names match exactly

### "Failed to load model" error
- Ensure model was converted with `minimum_deployment_target=ct.target.iOS17`
- Check device has enough RAM (Opus-MT needs ~500MB)

### Conversion fails
- Update coremltools: `pip install --upgrade coremltools`
- Check PyTorch version compatibility
- Try with `--quantize none` first

---

## Performance Tips

1. **Use Float16 quantization** - Half the size, minimal quality loss
2. **Pre-compile models** - Use `xcrun coremlcompiler` for faster load
3. **Load on demand** - Don't load all models at startup
4. **Use Neural Engine** - Set `computeUnits = .all` in MLModelConfiguration

---

## Alternative: On-Demand Download (One-Click Distribution)

Instead of bundling all models (which makes the app huge), you can host them on Hugging Face. This allows users to download only the languages they need with "one click" inside the app.

### Step 1: Prepare your Hugging Face Repository
1. Create a **Dataset** repository on Hugging Face (e.g., `yourusername/coreml-models`).
2. Make sure it's public (or private if you handle authentication in the app).

### Step 2: Run the One-Click Publish Script
This script converts all common models, compiles them for iOS, and zips them for distribution.

```bash
cd MLModels
# Replace with your actual HF username and repo name
./publish_all.sh --repo yourusername/coreml-models
```

### Step 3: Upload to Hugging Face
Once the script finishes, everything is in the `dist/` folder. Upload it:

```bash
# You'll need to run 'huggingface-cli login' first
python hf_upload.py --repo yourusername/coreml-models
```

### Step 4: Configure the iOS App
1. Open `iOS/TranslateLocal/Services/CoreMLModelDownloader.swift`.
2. Update the `huggingFaceRepo` variable:

```swift
private let huggingFaceRepo = "yourusername/coreml-models"
```

### How it works for the User:
1. When the user opens the "Download Models" screen, the app fetches `registry.json` from your HF repo.
2. It shows the list of available models (Opus pairs and Gemma).
3. The user taps "Download", the app fetches the `.zip`, extracts the `.mlmodelc`, and it's ready for local translation instantly!
