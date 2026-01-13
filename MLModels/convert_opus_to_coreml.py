#!/usr/bin/env python3
"""
Convert Helsinki-NLP Opus-MT models to Core ML format.

Usage:
    python convert_opus_to_coreml.py --model en-es --output ../Resources/Models/
    python convert_opus_to_coreml.py --model es-en --output ../Resources/Models/
    python convert_opus_to_coreml.py --all --output ../Resources/Models/

Supported models:
    - en-es, es-en (English ↔ Spanish)
    - en-ja, ja-en (English ↔ Japanese)
    - en-zh, zh-en (English ↔ Chinese)
    - en-fr, fr-en (English ↔ French)
    - en-de, de-en (English ↔ German)
    - And many more!
"""

import argparse
import os
import sys
from pathlib import Path

try:
    import torch
    import coremltools as ct
    from transformers import MarianMTModel, MarianTokenizer
    import numpy as np
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Install with: pip install -r requirements.txt")
    sys.exit(1)

# Model mappings (HuggingFace model IDs)
# These are used as fallback if local raw_models/ folder doesn't exist
OPUS_MODELS = {
    # English ↔ Spanish
    "en-es": "Helsinki-NLP/opus-mt-en-es",
    "es-en": "Helsinki-NLP/opus-mt-es-en",
    
    # English ↔ Japanese (note: HF uses "jap" not "ja")
    "en-ja": "Helsinki-NLP/opus-mt-en-jap",
    "ja-en": "Helsinki-NLP/opus-mt-jap-en",
    
    # English ↔ Chinese
    "en-zh": "Helsinki-NLP/opus-mt-en-zh",
    "zh-en": "Helsinki-NLP/opus-mt-zh-en",
    
    # English ↔ French
    "en-fr": "Helsinki-NLP/opus-mt-en-fr",
    "fr-en": "Helsinki-NLP/opus-mt-fr-en",
    
    # English ↔ German
    "en-de": "Helsinki-NLP/opus-mt-en-de",
    "de-en": "Helsinki-NLP/opus-mt-de-en",
    
    # Korean → English (standard model)
    "ko-en": "Helsinki-NLP/opus-mt-ko-en",
    
    # English ↔ Italian
    "en-it": "Helsinki-NLP/opus-mt-en-it",
    "it-en": "Helsinki-NLP/opus-mt-it-en",
    
    # English ↔ Portuguese
    "en-pt": "Helsinki-NLP/opus-mt-en-pt",
    "pt-en": "Helsinki-NLP/opus-mt-ROMANCE-en",
    
    # English ↔ Russian
    "en-ru": "Helsinki-NLP/opus-mt-en-ru",
    "ru-en": "Helsinki-NLP/opus-mt-ru-en",
    
    # English ↔ Arabic
    "en-ar": "Helsinki-NLP/opus-mt-en-ar",
    "ar-en": "Helsinki-NLP/opus-mt-ar-en",
    
    # English ↔ Hindi
    "en-hi": "Helsinki-NLP/opus-mt-en-hi",
    "hi-en": "Helsinki-NLP/opus-mt-hi-en",
}

# Bundle these models by default
DEFAULT_BUNDLE_MODELS = ["en-es", "es-en"]


class OpusModelConverter:
    def __init__(self, model_name: str, hf_model_id: str):
        self.model_name = model_name
        self.hf_model_id = hf_model_id
        self.model = None
        self.tokenizer = None
        
    def load_model(self):
        """Load the model and tokenizer (prefers local path if available)."""
        # Check if a local version exists in raw_models
        local_path = Path("raw_models") / self.model_name
        load_path = str(local_path) if local_path.exists() else self.hf_model_id
        
        if local_path.exists():
            print(f"📂 Found local model at {local_path}. Using local files.")
        else:
            print(f"📥 Loading from HuggingFace: {self.hf_model_id}...")
            
        self.tokenizer = MarianTokenizer.from_pretrained(load_path)
        self.model = MarianMTModel.from_pretrained(load_path)
        self.model.eval()
        print(f"✅ Model loaded successfully")
        
    def trace_encoder(self, max_length: int = 512):
        """Trace the encoder part of the model."""
        print("🔄 Tracing encoder...")
        
        # Create dummy inputs
        dummy_input_ids = torch.randint(0, self.model.config.vocab_size, (1, max_length))
        dummy_attention_mask = torch.ones(1, max_length, dtype=torch.long)
        
        class EncoderWrapper(torch.nn.Module):
            def __init__(self, encoder):
                super().__init__()
                self.encoder = encoder
                
            def forward(self, input_ids, attention_mask):
                outputs = self.encoder(
                    input_ids=input_ids,
                    attention_mask=attention_mask,
                    return_dict=True
                )
                return outputs.last_hidden_state
        
        encoder_wrapper = EncoderWrapper(self.model.model.encoder)
        encoder_wrapper.eval()
        
        traced_encoder = torch.jit.trace(
            encoder_wrapper,
            (dummy_input_ids, dummy_attention_mask)
        )
        
        return traced_encoder
    
    def trace_decoder(self, max_length: int = 512):
        """Trace the decoder part of the model."""
        print("🔄 Tracing decoder...")
        
        # Create dummy inputs
        dummy_decoder_input_ids = torch.randint(0, self.model.config.vocab_size, (1, 1))
        dummy_encoder_hidden = torch.randn(1, max_length, self.model.config.d_model)
        dummy_encoder_attention_mask = torch.ones(1, max_length, dtype=torch.long)
        
        class DecoderWrapper(torch.nn.Module):
            def __init__(self, decoder, lm_head):
                super().__init__()
                self.decoder = decoder
                self.lm_head = lm_head
                
            def forward(self, decoder_input_ids, encoder_hidden_states, encoder_attention_mask):
                outputs = self.decoder(
                    input_ids=decoder_input_ids,
                    encoder_hidden_states=encoder_hidden_states,
                    encoder_attention_mask=encoder_attention_mask,
                    return_dict=True
                )
                logits = self.lm_head(outputs.last_hidden_state)
                return logits
        
        decoder_wrapper = DecoderWrapper(self.model.model.decoder, self.model.lm_head)
        decoder_wrapper.eval()
        
        traced_decoder = torch.jit.trace(
            decoder_wrapper,
            (dummy_decoder_input_ids, dummy_encoder_hidden, dummy_encoder_attention_mask)
        )
        
        return traced_decoder
    
    def convert_to_coreml(self, output_dir: str, quantize: str = "float16"):
        """Convert the model to Core ML format."""
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        model_output_name = f"OpusMT_{self.model_name.replace('-', '_')}"
        
        # Set compute precision based on quantize parameter
        if quantize == "float16":
            compute_precision = ct.precision.FLOAT16
            print("📊 Using FLOAT16 precision for smaller model size")
        else:
            compute_precision = ct.precision.FLOAT32
            print("📊 Using FLOAT32 precision")
        
        # Convert encoder
        print("🔄 Converting encoder to Core ML...")
        traced_encoder = self.trace_encoder()
        
        encoder_inputs = [
            ct.TensorType(name="input_ids", shape=(1, ct.RangeDim(1, 512)), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, ct.RangeDim(1, 512)), dtype=np.int32),
        ]
        
        encoder_coreml = ct.convert(
            traced_encoder,
            inputs=encoder_inputs,
            outputs=[ct.TensorType(name="encoder_hidden_states")],
            minimum_deployment_target=ct.target.iOS17,
            convert_to="mlprogram",
            compute_precision=compute_precision,
            compute_units=ct.ComputeUnit.ALL,
        )
        
        encoder_path = output_path / f"{model_output_name}_encoder.mlpackage"
        encoder_coreml.save(str(encoder_path))
        print(f"✅ Encoder saved to {encoder_path}")
        
        # Convert decoder
        print("🔄 Converting decoder to Core ML...")
        traced_decoder = self.trace_decoder()
        
        decoder_inputs = [
            ct.TensorType(name="decoder_input_ids", shape=(1, ct.RangeDim(1, 512)), dtype=np.int32),
            ct.TensorType(name="encoder_hidden_states", shape=(1, ct.RangeDim(1, 512), self.model.config.d_model), dtype=np.float32),
            ct.TensorType(name="encoder_attention_mask", shape=(1, ct.RangeDim(1, 512)), dtype=np.int32),
        ]
        
        decoder_coreml = ct.convert(
            traced_decoder,
            inputs=decoder_inputs,
            outputs=[ct.TensorType(name="logits")],
            minimum_deployment_target=ct.target.iOS17,
            convert_to="mlprogram",
            compute_precision=compute_precision,
            compute_units=ct.ComputeUnit.ALL,
        )
        
        decoder_path = output_path / f"{model_output_name}_decoder.mlpackage"
        decoder_coreml.save(str(decoder_path))
        print(f"✅ Decoder saved to {decoder_path}")
        
        # Save tokenizer config
        self.save_tokenizer_config(output_path, model_output_name)
        
        return encoder_path, decoder_path
    
    def save_tokenizer_config(self, output_path: Path, model_name: str):
        """Save tokenizer configuration for the iOS app."""
        import json
        
        config = {
            "model_name": model_name,
            "vocab_size": self.model.config.vocab_size,
            "pad_token_id": self.tokenizer.pad_token_id,
            "eos_token_id": self.tokenizer.eos_token_id,
            "decoder_start_token_id": self.model.config.decoder_start_token_id,
            "max_length": 512,
        }
        
        config_path = output_path / f"{model_name}_config.json"
        with open(config_path, "w") as f:
            json.dump(config, f, indent=2)
        
        # Also save the vocabulary
        vocab_path = output_path / f"{model_name}_vocab.json"
        with open(vocab_path, "w") as f:
            json.dump(self.tokenizer.get_vocab(), f)
        
        print(f"✅ Config saved to {config_path}")


def main():
    parser = argparse.ArgumentParser(description="Convert Opus-MT models to Core ML")
    parser.add_argument(
        "--model",
        type=str,
        help="Model to convert (e.g., 'en-es', 'es-en')",
        choices=list(OPUS_MODELS.keys())
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="Convert all default bundle models"
    )
    parser.add_argument(
        "--output",
        type=str,
        default="./converted_models",
        help="Output directory for converted models"
    )
    parser.add_argument(
        "--quantize",
        type=str,
        default="float16",
        choices=["none", "float16"],
        help="Quantization type"
    )
    
    args = parser.parse_args()
    
    if args.all:
        models_to_convert = DEFAULT_BUNDLE_MODELS
    elif args.model:
        models_to_convert = [args.model]
    else:
        print("❌ Please specify --model or --all")
        parser.print_help()
        sys.exit(1)
    
    print(f"🚀 Converting {len(models_to_convert)} model(s)...")
    print(f"📁 Output directory: {args.output}")
    print()
    
    for model_name in models_to_convert:
        print(f"\n{'='*50}")
        print(f"Converting: {model_name}")
        print(f"{'='*50}")
        
        hf_model_id = OPUS_MODELS[model_name]
        converter = OpusModelConverter(model_name, hf_model_id)
        
        try:
            converter.load_model()
            converter.convert_to_coreml(args.output, args.quantize)
            print(f"✅ {model_name} converted successfully!")
        except Exception as e:
            print(f"❌ Failed to convert {model_name}: {e}")
            continue
    
    print(f"\n🎉 Conversion complete!")
    print(f"\n📋 Next steps:")
    print(f"1. Copy the .mlpackage files to your Xcode project")
    print(f"2. Add them to the 'Resources/Models' group")
    print(f"3. Ensure they're included in the app bundle")


if __name__ == "__main__":
    main()
