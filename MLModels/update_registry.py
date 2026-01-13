import json
import os
import sys
from pathlib import Path
from datetime import datetime

def update_registry(model_metadata, dist_dir="dist"):
    registry_path = Path(dist_dir) / "registry.json"
    
    if registry_path.exists():
        with open(registry_path, "r") as f:
            try:
                registry = json.load(f)
            except json.JSONDecodeError:
                registry = {"models": [], "lastUpdated": ""}
    else:
        registry = {"models": [], "lastUpdated": ""}
    
    # Update or add the model
    existing_model_idx = -1
    for i, model in enumerate(registry["models"]):
        if model["id"] == model_metadata["id"]:
            existing_model_idx = i
            break
            
    if existing_model_idx >= 0:
        registry["models"][existing_model_idx] = model_metadata
    else:
        registry["models"].append(model_metadata)
        
    registry["lastUpdated"] = datetime.now().strftime("%Y-%m-%d")
    
    with open(registry_path, "w") as f:
        json.dump(registry, f, indent=2)
    
    print(f"✅ Updated registry.json at {registry_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python update_registry.py '<json_metadata>'")
        sys.exit(1)
        
    metadata = json.loads(sys.argv[1])
    update_registry(metadata)
