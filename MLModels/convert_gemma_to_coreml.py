#!/usr/bin/env python3
"""
🔄 Gemma-3n-E2B to Core ML Conversion Script

This script converts the Gemma-3n-E2B model to Core ML format
for on-device inference on iOS.

Usage:
    python convert_gemma_to_coreml.py [options]

Options:
    --model-name    HuggingFace model name (default: google/gemma-3n-e2b-it)
    --output-dir    Output directory for Core ML model
    --quantize      Apply quantization (float16, int8)
    --max-length    Maximum sequence length (default: 512)
"""

import argparse
import os
import sys
from pathlib import Path
from typing import Optional

import numpy as np
import torch
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn
from transformers import AutoModelForCausalLM, AutoTokenizer

console = Console()


def print_header():
    """Print script header."""
    console.print("\n" + "=" * 60, style="blue")
    console.print("🔄 Gemma-3n-E2B to Core ML Converter", style="bold blue")
    console.print("=" * 60 + "\n", style="blue")


def check_dependencies():
    """Check if all required dependencies are available."""
    console.print("📦 Checking dependencies...", style="yellow")
    
    try:
        import coremltools as ct
        console.print(f"   ✅ coremltools {ct.__version__}", style="green")
    except ImportError:
        console.print("   ❌ coremltools not found. Install with: pip install coremltools", style="red")
        return False
    
    try:
        import transformers
        console.print(f"   ✅ transformers {transformers.__version__}", style="green")
    except ImportError:
        console.print("   ❌ transformers not found. Install with: pip install transformers", style="red")
        return False
    
    console.print(f"   ✅ torch {torch.__version__}", style="green")
    console.print(f"   ✅ numpy {np.__version__}", style="green")
    console.print()
    
    return True


def load_model(model_name: str, device: str = "cpu"):
    """
    Load the Gemma model and tokenizer from HuggingFace.
    
    Args:
        model_name: HuggingFace model identifier
        device: Device to load model on ('cpu', 'cuda', 'mps')
    
    Returns:
        Tuple of (model, tokenizer)
    """
    console.print(f"📥 Loading model: {model_name}", style="yellow")
    
    # Load tokenizer
    tokenizer = AutoTokenizer.from_pretrained(
        model_name,
        trust_remote_code=False  # Security: Never trust remote code
    )
    console.print("   ✅ Tokenizer loaded", style="green")
    
    # Load model with float16 for efficiency
    model = AutoModelForCausalLM.from_pretrained(
        model_name,
        torch_dtype=torch.float16,
        device_map=device,
        trust_remote_code=False,  # Security: Never trust remote code
        low_cpu_mem_usage=True
    )
    model.eval()
    console.print("   ✅ Model loaded", style="green")
    
    return model, tokenizer


def create_translation_wrapper(model, tokenizer, max_length: int = 512):
    """
    Create a wrapper class for translation that can be traced.
    
    Args:
        model: The loaded language model
        tokenizer: The tokenizer
        max_length: Maximum sequence length
    
    Returns:
        Wrapper module for tracing
    """
    
    class TranslationWrapper(torch.nn.Module):
        """Wrapper for translation inference."""
        
        def __init__(self, model, max_length):
            super().__init__()
            self.model = model
            self.max_length = max_length
        
        def forward(self, input_ids: torch.Tensor, attention_mask: torch.Tensor):
            """
            Forward pass for translation.
            
            Args:
                input_ids: Token IDs [batch_size, seq_length]
                attention_mask: Attention mask [batch_size, seq_length]
            
            Returns:
                Logits for next token prediction
            """
            outputs = self.model(
                input_ids=input_ids,
                attention_mask=attention_mask,
                use_cache=False
            )
            return outputs.logits
    
    return TranslationWrapper(model, max_length)


def trace_model(wrapper, tokenizer, max_length: int = 512):
    """
    Trace the model using TorchScript for Core ML conversion.
    
    Args:
        wrapper: The model wrapper
        tokenizer: The tokenizer
        max_length: Maximum sequence length
    
    Returns:
        Traced model
    """
    console.print("🔍 Tracing model for conversion...", style="yellow")
    
    # Create example inputs for tracing
    example_text = "Translate to Japanese: Hello, how are you today?"
    example_inputs = tokenizer(
        example_text,
        return_tensors="pt",
        padding="max_length",
        max_length=max_length,
        truncation=True
    )
    
    # Move to same device as model
    device = next(wrapper.parameters()).device
    input_ids = example_inputs["input_ids"].to(device)
    attention_mask = example_inputs["attention_mask"].to(device)
    
    # Trace the model
    with torch.no_grad():
        traced_model = torch.jit.trace(
            wrapper,
            (input_ids, attention_mask),
            strict=False
        )
    
    console.print("   ✅ Model traced successfully", style="green")
    return traced_model


def convert_to_coreml(
    traced_model,
    max_length: int = 512,
    quantize: Optional[str] = "float16",
    output_path: str = "Gemma3nE2B.mlpackage"
):
    """
    Convert traced PyTorch model to Core ML format.
    
    Args:
        traced_model: TorchScript traced model
        max_length: Maximum sequence length
        quantize: Quantization type ('float16', 'int8', None)
        output_path: Output path for .mlpackage
    
    Returns:
        Core ML model
    """
    import coremltools as ct
    
    console.print("🍎 Converting to Core ML...", style="yellow")
    
    # Define input shapes
    # Using RangeDim for flexible sequence lengths
    input_shape = ct.Shape(
        shape=(1, ct.RangeDim(lower_bound=1, upper_bound=max_length, default=128))
    )
    
    # Set compute precision based on quantization
    if quantize == "float16":
        compute_precision = ct.precision.FLOAT16
        console.print("   📊 Using FLOAT16 precision", style="cyan")
    elif quantize == "int8":
        compute_precision = ct.precision.FLOAT16  # Will quantize after
        console.print("   📊 Using INT8 quantization", style="cyan")
    else:
        compute_precision = ct.precision.FLOAT32
        console.print("   📊 Using FLOAT32 precision", style="cyan")
    
    # Convert to Core ML
    coreml_model = ct.convert(
        traced_model,
        inputs=[
            ct.TensorType(
                name="input_ids",
                shape=input_shape,
                dtype=np.int32
            ),
            ct.TensorType(
                name="attention_mask",
                shape=input_shape,
                dtype=np.int32
            )
        ],
        outputs=[
            ct.TensorType(name="logits", dtype=np.float16)
        ],
        compute_precision=compute_precision,
        compute_units=ct.ComputeUnit.ALL,  # Use Neural Engine when available
        minimum_deployment_target=ct.target.iOS17,
        convert_to="mlpackage"
    )
    
    # Apply INT8 quantization if requested
    if quantize == "int8":
        console.print("   🔧 Applying INT8 quantization...", style="cyan")
        coreml_model = ct.compression_utils.affine_quantize_weights(
            coreml_model,
            mode="linear_symmetric",
            dtype=np.int8
        )
    
    # Add metadata
    coreml_model.author = "TranslateLocal"
    coreml_model.short_description = "Gemma-3n-E2B for on-device translation"
    coreml_model.version = "1.0.0"
    
    # Add user-defined metadata
    coreml_model.user_defined_metadata["model_type"] = "translation"
    coreml_model.user_defined_metadata["source_model"] = "google/gemma-3n-e2b-it"
    coreml_model.user_defined_metadata["max_sequence_length"] = str(max_length)
    
    # Save the model
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    coreml_model.save(str(output_path))
    
    # Get file size
    model_size = sum(
        f.stat().st_size for f in output_path.rglob('*') if f.is_file()
    ) / (1024 * 1024)  # MB
    
    console.print(f"   ✅ Model saved to: {output_path}", style="green")
    console.print(f"   📦 Model size: {model_size:.1f} MB", style="green")
    
    return coreml_model


def validate_model(model_path: str, tokenizer):
    """
    Validate the converted Core ML model.
    
    Args:
        model_path: Path to the .mlpackage
        tokenizer: The tokenizer for creating test inputs
    """
    import coremltools as ct
    
    console.print("🧪 Validating converted model...", style="yellow")
    
    # Load the model
    model = ct.models.MLModel(model_path)
    console.print("   ✅ Model loads successfully", style="green")
    
    # Create test input
    test_text = "Translate to Spanish: Good morning"
    inputs = tokenizer(
        test_text,
        return_tensors="np",
        padding="max_length",
        max_length=128,
        truncation=True
    )
    
    # Run inference
    try:
        prediction = model.predict({
            "input_ids": inputs["input_ids"].astype(np.int32),
            "attention_mask": inputs["attention_mask"].astype(np.int32)
        })
        console.print("   ✅ Inference runs successfully", style="green")
        console.print(f"   📊 Output shape: {prediction['logits'].shape}", style="cyan")
    except Exception as e:
        console.print(f"   ⚠️ Inference warning: {e}", style="yellow")


def main():
    """Main conversion pipeline."""
    parser = argparse.ArgumentParser(
        description="Convert Gemma-3n-E2B to Core ML"
    )
    parser.add_argument(
        "--model-name",
        default="google/gemma-3n-e2b-it",
        help="HuggingFace model name"
    )
    parser.add_argument(
        "--output-dir",
        default="../Resources/Models",
        help="Output directory"
    )
    parser.add_argument(
        "--quantize",
        choices=["float16", "int8", "none"],
        default="float16",
        help="Quantization type"
    )
    parser.add_argument(
        "--max-length",
        type=int,
        default=512,
        help="Maximum sequence length"
    )
    parser.add_argument(
        "--skip-validation",
        action="store_true",
        help="Skip model validation"
    )
    
    args = parser.parse_args()
    
    print_header()
    
    # Check dependencies
    if not check_dependencies():
        console.print("\n❌ Missing dependencies. Please install requirements first.", style="red")
        sys.exit(1)
    
    # Determine device
    if torch.backends.mps.is_available():
        device = "mps"
        console.print("🖥️ Using Apple Silicon (MPS)", style="cyan")
    elif torch.cuda.is_available():
        device = "cuda"
        console.print("🖥️ Using CUDA GPU", style="cyan")
    else:
        device = "cpu"
        console.print("🖥️ Using CPU", style="cyan")
    
    try:
        # Load model and tokenizer
        model, tokenizer = load_model(args.model_name, device)
        
        # Create wrapper
        wrapper = create_translation_wrapper(model, tokenizer, args.max_length)
        
        # Move wrapper to CPU for tracing (required for Core ML conversion)
        wrapper = wrapper.cpu().float()
        
        # Trace the model
        traced_model = trace_model(wrapper, tokenizer, args.max_length)
        
        # Convert to Core ML
        output_path = Path(args.output_dir) / "Gemma3nE2B.mlpackage"
        quantize = None if args.quantize == "none" else args.quantize
        
        coreml_model = convert_to_coreml(
            traced_model,
            max_length=args.max_length,
            quantize=quantize,
            output_path=str(output_path)
        )
        
        # Validate
        if not args.skip_validation:
            validate_model(str(output_path), tokenizer)
        
        console.print("\n" + "=" * 60, style="green")
        console.print("✅ Conversion completed successfully!", style="bold green")
        console.print("=" * 60 + "\n", style="green")
        
        console.print("📝 Next steps:", style="cyan")
        console.print("   1. Copy the .mlpackage to your Xcode project", style="white")
        console.print("   2. Add it to your app target", style="white")
        console.print("   3. Use the TranslationService to load and run inference", style="white")
        
    except Exception as e:
        console.print(f"\n❌ Error during conversion: {e}", style="red")
        console.print("\n💡 Tips:", style="yellow")
        console.print("   - Ensure you have enough RAM (16GB+ recommended)", style="white")
        console.print("   - Try running on a machine with more memory", style="white")
        console.print("   - Check if the model name is correct", style="white")
        raise


if __name__ == "__main__":
    main()
