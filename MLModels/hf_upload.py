import os
import sys
import argparse
from pathlib import Path
from huggingface_hub import HfApi, create_repo, login

def upload_to_hf(repo_id, folder_path, token=None):
    """Uploads the contents of a folder to a Hugging Face repository."""
    api = HfApi()
    
    print(f"🚀 Uploading models from {folder_path} to {repo_id}...")
    
    try:
        # Ensure repo exists
        try:
            create_repo(repo_id, repo_type="dataset", exist_ok=True, token=token)
            print(f"✅ Repository {repo_id} is ready.")
        except Exception as e:
            print(f"ℹ️ Repository might already exist or error: {e}")

        # Upload all files in the folder
        api.upload_folder(
            folder_path=folder_path,
            repo_id=repo_id,
            repo_type="dataset",
            token=token
        )
        
        print(f"🎉 Successfully uploaded everything to https://huggingface.co/datasets/{repo_id}")
        print(f"🔗 Your registry.json is at: https://huggingface.co/datasets/{repo_id}/resolve/main/registry.json")
        
    except Exception as e:
        print(f"❌ Error during upload: {e}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Upload models to Hugging Face")
    parser.add_argument("--repo", required=True, help="Hugging Face repo ID (e.g., username/repo-name)")
    parser.add_argument("--folder", default="dist", help="Folder to upload")
    parser.add_argument("--token", help="Hugging Face API token")
    
    args = parser.parse_args()
    
    upload_to_hf(args.repo, args.folder, args.token)
