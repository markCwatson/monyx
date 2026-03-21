"""
Download AnimalClue YOLOv11 models from HuggingFace and export to TFLite.
Also extracts class name mappings.

Usage:
  python tools/export_models.py

Requires: pip install ultralytics huggingface_hub
"""

import json, os, sys
from pathlib import Path


def main():
    try:
        from huggingface_hub import hf_hub_download
        from ultralytics import YOLO
    except ImportError:
        print("Installing required packages...")
        os.system(f"{sys.executable} -m pip install ultralytics huggingface_hub")
        from huggingface_hub import hf_hub_download
        from ultralytics import YOLO

    out_dir = Path(__file__).parent.parent / "assets" / "models"
    out_dir.mkdir(parents=True, exist_ok=True)

    models = {
        "footprint": "risashinoda/footprint_yolo",
        "feces": "risashinoda/feces_yolo",
    }

    for name, repo in models.items():
        print(f"\n{'='*60}")
        print(f"Processing {name} model from {repo}")
        print(f"{'='*60}")

        # Download weights (footprint repo has best.pt, feces repo only has last.pt)
        for weight_name in ("best.pt", "last.pt"):
            try:
                pt_path = hf_hub_download(repo_id=repo, filename=weight_name)
                print(f"Downloaded: {pt_path}")
                break
            except Exception:
                continue
        else:
            print(f"ERROR: No weights found in {repo}")
            sys.exit(1)

        # Load model
        model = YOLO(pt_path)

        # Extract class names
        class_names = model.names  # dict: {0: 'species', 1: 'species', ...}
        class_file = out_dir / f"{name}_classes.json"
        with open(class_file, "w") as f:
            json.dump(class_names, f, indent=2)
        print(f"Saved {len(class_names)} classes to {class_file}")

        # Export to TFLite (float16 for best accuracy/size balance)
        print(f"Exporting to TFLite (float16)...")
        export_path = model.export(format="tflite", imgsz=640, half=True)
        print(f"Exported to: {export_path}")

        # Copy to assets
        import shutil

        dest = out_dir / f"{name}_det_float16.tflite"
        shutil.copy2(export_path, dest)
        print(f"Copied to: {dest}")
        print(f"Size: {dest.stat().st_size / 1024 / 1024:.1f} MB")

    print(f"\n{'='*60}")
    print(f"All models exported to {out_dir}")
    print(f"Files:")
    for f in sorted(out_dir.iterdir()):
        print(f"  {f.name} ({f.stat().st_size / 1024 / 1024:.1f} MB)")


if __name__ == "__main__":
    main()
