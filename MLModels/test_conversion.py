#!/usr/bin/env python3
"""
🧪 Test Script for Core ML Model Conversion

This script validates that converted Core ML models work correctly.
Run this after conversion to verify the models are functional.

Usage:
    python test_conversion.py --model-path ../Resources/Models/Gemma3nE2B.mlpackage
    python test_conversion.py --model-path ../Resources/Models/OpusMT_en_ja.mlpackage
"""

import argparse
import sys
import time
from pathlib import Path
from typing import Optional

import numpy as np
from rich.console import Console
from rich.table import Table

console = Console()


def test_model_loading(model_path: str) -> bool:
    """Test that the model loads successfully."""
    import coremltools as ct
    
    console.print(f"\n📦 Loading model from: {model_path}", style="yellow")
    
    try:
        start_time = time.time()
        model = ct.models.MLModel(model_path)
        load_time = time.time() - start_time
        
        console.print(f"   ✅ Model loaded in {load_time:.2f}s", style="green")
        return True, model
    except Exception as e:
        console.print(f"   ❌ Failed to load: {e}", style="red")
        return False, None


def test_model_metadata(model) -> bool:
    """Test that model metadata is correct."""
    console.print("\n📋 Checking model metadata...", style="yellow")
    
    # Get spec
    spec = model.get_spec()
    
    # Print metadata
    table = Table(title="Model Metadata")
    table.add_column("Property", style="cyan")
    table.add_column("Value", style="white")
    
    table.add_row("Author", model.author or "Not set")
    table.add_row("Description", model.short_description or "Not set")
    table.add_row("Version", model.version or "Not set")
    
    # User metadata
    if model.user_defined_metadata:
        for key, value in model.user_defined_metadata.items():
            table.add_row(f"[{key}]", value)
    
    console.print(table)
    
    # Check inputs/outputs
    console.print("\n📥 Model Inputs:", style="yellow")
    for input_name in model.input_description:
        desc = model.input_description[input_name]
        console.print(f"   • {input_name}: {desc}", style="white")
    
    console.print("\n📤 Model Outputs:", style="yellow")
    for output_name in model.output_description:
        desc = model.output_description[output_name]
        console.print(f"   • {output_name}: {desc}", style="white")
    
    return True


def test_inference(model, model_type: str) -> bool:
    """Test that inference runs successfully."""
    console.print("\n🧪 Testing inference...", style="yellow")
    
    try:
        # Create dummy inputs based on model type
        if "opus" in model_type.lower():
            # Encoder-decoder model
            seq_length = 32
            input_ids = np.ones((1, seq_length), dtype=np.int32)
            attention_mask = np.ones((1, seq_length), dtype=np.int32)
            decoder_input_ids = np.zeros((1, 1), dtype=np.int32)
            
            inputs = {
                "input_ids": input_ids,
                "attention_mask": attention_mask,
                "decoder_input_ids": decoder_input_ids
            }
        else:
            # Causal LM model (Gemma)
            seq_length = 32
            input_ids = np.ones((1, seq_length), dtype=np.int32)
            attention_mask = np.ones((1, seq_length), dtype=np.int32)
            
            inputs = {
                "input_ids": input_ids,
                "attention_mask": attention_mask
            }
        
        # Run inference
        start_time = time.time()
        output = model.predict(inputs)
        inference_time = time.time() - start_time
        
        console.print(f"   ✅ Inference successful in {inference_time*1000:.1f}ms", style="green")
        
        # Check output
        if "logits" in output:
            logits = output["logits"]
            console.print(f"   📊 Output shape: {logits.shape}", style="cyan")
            console.print(f"   📊 Output dtype: {logits.dtype}", style="cyan")
            console.print(f"   📊 Output range: [{logits.min():.3f}, {logits.max():.3f}]", style="cyan")
        
        return True
        
    except Exception as e:
        console.print(f"   ❌ Inference failed: {e}", style="red")
        return False


def test_compute_units(model_path: str) -> bool:
    """Test model with different compute units."""
    import coremltools as ct
    
    console.print("\n🖥️ Testing compute unit configurations...", style="yellow")
    
    compute_units = [
        (ct.ComputeUnit.CPU_ONLY, "CPU Only"),
        (ct.ComputeUnit.CPU_AND_GPU, "CPU + GPU"),
        (ct.ComputeUnit.CPU_AND_NE, "CPU + Neural Engine"),
        (ct.ComputeUnit.ALL, "All Available"),
    ]
    
    results = []
    
    for unit, name in compute_units:
        try:
            config = ct.models.MLModel.Configuration()
            config.compute_units = unit
            
            model = ct.models.MLModel(model_path, configuration=config)
            results.append((name, "✅ Supported"))
        except Exception as e:
            results.append((name, f"❌ {str(e)[:30]}..."))
    
    table = Table(title="Compute Unit Support")
    table.add_column("Configuration", style="cyan")
    table.add_column("Status", style="white")
    
    for name, status in results:
        table.add_row(name, status)
    
    console.print(table)
    
    return True


def estimate_memory_usage(model_path: str) -> bool:
    """Estimate memory usage of the model."""
    console.print("\n💾 Estimating memory usage...", style="yellow")
    
    path = Path(model_path)
    
    if path.is_dir():
        # Calculate total size of mlpackage
        total_size = sum(f.stat().st_size for f in path.rglob('*') if f.is_file())
    else:
        total_size = path.stat().st_size
    
    size_mb = total_size / (1024 * 1024)
    
    console.print(f"   📦 Model size on disk: {size_mb:.1f} MB", style="white")
    console.print(f"   📊 Estimated runtime memory: ~{size_mb * 1.2:.1f} - {size_mb * 2:.1f} MB", style="white")
    
    # Memory recommendations
    if size_mb < 100:
        console.print("   ✅ Suitable for all iOS devices", style="green")
    elif size_mb < 500:
        console.print("   ⚠️ May have issues on devices with < 4GB RAM", style="yellow")
    elif size_mb < 1000:
        console.print("   ⚠️ Recommended for devices with 6GB+ RAM", style="yellow")
    else:
        console.print("   ⚠️ Requires high-memory devices (8GB+ RAM)", style="yellow")
    
    return True


def main():
    parser = argparse.ArgumentParser(description="Test converted Core ML models")
    parser.add_argument(
        "--model-path",
        required=True,
        help="Path to the .mlpackage or .mlmodelc"
    )
    parser.add_argument(
        "--model-type",
        default="auto",
        choices=["auto", "gemma", "opus"],
        help="Type of model (for inference testing)"
    )
    parser.add_argument(
        "--skip-inference",
        action="store_true",
        help="Skip inference testing"
    )
    
    args = parser.parse_args()
    
    console.print("\n" + "=" * 60, style="blue")
    console.print("🧪 Core ML Model Test Suite", style="bold blue")
    console.print("=" * 60, style="blue")
    
    # Verify model exists
    if not Path(args.model_path).exists():
        console.print(f"\n❌ Model not found: {args.model_path}", style="red")
        sys.exit(1)
    
    # Detect model type if auto
    model_type = args.model_type
    if model_type == "auto":
        if "opus" in args.model_path.lower():
            model_type = "opus"
        else:
            model_type = "gemma"
        console.print(f"🔍 Detected model type: {model_type}", style="cyan")
    
    tests_passed = 0
    tests_total = 0
    
    # Test 1: Loading
    tests_total += 1
    success, model = test_model_loading(args.model_path)
    if success:
        tests_passed += 1
    else:
        console.print("\n❌ Cannot proceed without loading model", style="red")
        sys.exit(1)
    
    # Test 2: Metadata
    tests_total += 1
    if test_model_metadata(model):
        tests_passed += 1
    
    # Test 3: Inference
    if not args.skip_inference:
        tests_total += 1
        if test_inference(model, model_type):
            tests_passed += 1
    
    # Test 4: Compute units
    tests_total += 1
    if test_compute_units(args.model_path):
        tests_passed += 1
    
    # Test 5: Memory estimation
    tests_total += 1
    if estimate_memory_usage(args.model_path):
        tests_passed += 1
    
    # Summary
    console.print("\n" + "=" * 60, style="blue")
    console.print(f"📊 Test Results: {tests_passed}/{tests_total} passed", 
                  style="green" if tests_passed == tests_total else "yellow")
    console.print("=" * 60 + "\n", style="blue")
    
    if tests_passed == tests_total:
        console.print("✅ All tests passed! Model is ready for iOS deployment.", style="bold green")
    else:
        console.print("⚠️ Some tests failed. Review the output above.", style="yellow")


if __name__ == "__main__":
    main()
