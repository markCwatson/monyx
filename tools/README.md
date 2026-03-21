# tools/ — Model Export Pipeline

This directory contains the Python tooling used to download and convert the [AnimalClue](https://github.com/dahlian00/AnimalClue) YOLOv11 models into TFLite format for on-device inference in the Monyx app.

## Background

Monyx includes an **animal track identification** feature that runs entirely on-device. It uses YOLOv11 object-detection models from the [AnimalClue project (ICCV 2025)](https://dahlian00.github.io/AnimalCluePage/) to classify species from photos of animal tracks.

Two models are used:

| Model         | HuggingFace Repo                                                                | Species | Output Shape     | TFLite Size |
| ------------- | ------------------------------------------------------------------------------- | ------- | ---------------- | ----------- |
| **Footprint** | [risashinoda/footprint_yolo](https://huggingface.co/risashinoda/footprint_yolo) | 117     | `[1, 121, 8400]` | ~10 MB      |
| **Feces**     | [risashinoda/feces_yolo](https://huggingface.co/risashinoda/feces_yolo)         | 101     | `[1, 105, 8400]` | ~10 MB      |

The models are YOLOv11n (nano) checkpoints trained on the AnimalClue dataset. The output tensor has shape `[1, C, 8400]` where `C = 4 + num_classes` (4 bounding-box coordinates + per-class confidence scores) and 8400 is the number of proposal boxes.

## What the pipeline does

1. **Downloads** the `.pt` (PyTorch) weights from HuggingFace via `huggingface_hub`.
2. **Loads** the model with Ultralytics to extract the class-name mapping (`model.names`), saved as `<model>_classes.json`.
3. **Exports** from PyTorch → ONNX → TF SavedModel → TFLite (float16) using the Ultralytics export pipeline. The intermediate conversion chain is: `ultralytics` → `onnx` → `onnx2tf` → `ai-edge-litert`.
4. **Copies** the final `.tflite` files and class JSONs into `assets/models/` where Flutter bundles them.

### Output files

```
assets/models/
  footprint_det_float16.tflite   — 10 MB, input [1,640,640,3] NHWC float32
  footprint_classes.json         — {0: "American Alligator", 1: "American Badger", ...}
  feces_det_float16.tflite       — 10 MB, input [1,640,640,3] NHWC float32
  feces_classes.json             — {0: "American Alligator", 1: "American Badger", ...}
```

## How to reproduce

### Prerequisites

- Python 3.13+ (tested on macOS Apple Silicon)
- ~2 GB disk for the virtual environment and intermediate model files

### Steps

```bash
# 1. Create and activate a virtual environment
python3 -m venv tools/.venv
source tools/.venv/bin/activate

# 2. Install dependencies
pip install -r tools/requirements.txt

# 3. Run the export script
python tools/export_models.py
```

The script downloads the weights from HuggingFace (requires internet), converts them, and writes the four output files to `assets/models/`.

### Known issues

- **Feces model filename**: The `risashinoda/feces_yolo` repo only contains `last.pt` (not `best.pt`). The export script currently tries `best.pt` first. If this fails, download `last.pt` manually:
  ```python
  pt_path = hf_hub_download(repo_id='risashinoda/feces_yolo', filename='last.pt')
  ```
- **TensorFlow + Python 3.13**: Only TensorFlow ≥2.21 supports Python 3.13. The Ultralytics package may pin `tensorflow<=2.19` in some versions — the `requirements.txt` overrides this by installing TF 2.21+ directly.
- **Large intermediate files**: The ONNX → TF conversion creates temporary calibration data files (`.npy`) in the working directory. These can be deleted after export.

## Files

| File               | Purpose                                              |
| ------------------ | ---------------------------------------------------- |
| `export_models.py` | Main script — downloads, converts, and copies models |
| `requirements.txt` | Pinned Python dependencies for reproducible builds   |
| `.venv/`           | Python virtual environment (gitignored)              |
