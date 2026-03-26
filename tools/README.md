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

| File                         | Purpose                                                     |
| ---------------------------- | ----------------------------------------------------------- |
| `export_models.py`           | Track detector — downloads, converts, and copies models     |
| `build_plant_dataset.py`     | Plant classifier — curates dataset from iNaturalist         |
| `build_plant_metadata.py`    | Plant classifier — generates species metadata for reranking |
| `train_plant_classifier.py`  | Plant classifier — trains EfficientNet-Lite0                |
| `export_plant_classifier.py` | Plant classifier — exports PyTorch → TFLite                 |
| `build_land_tileset.py`      | Land overlay — downloads, normalizes, and tiles public land |
| `requirements.txt`           | Pinned Python dependencies for reproducible builds          |
| `land_requirements.txt`      | Python dependencies for the land overlay pipeline           |
| `.venv/`                     | Python 3.13 virtual environment (training, gitignored)      |
| `.export_venv/`              | Python 3.12 virtual environment (export, gitignored)        |

---

# Plant Classifier Pipeline

## Background

Monyx also includes an **on-device plant identification** feature for US and Canada species. Unlike the YOLO-based track detection, this uses an **EfficientNet-Lite0 image classifier** — no bounding boxes, just whole-image classification to identify species from photos of leaves, flowers, bark, fruit, or whole plants.

## Pipeline overview

The plant classifier pipeline has four scripts that run in sequence:

### 1. Dataset curation — `build_plant_dataset.py`

Downloads plant images from iNaturalist (research-grade observations, US + Canada only):

```bash
python tools/build_plant_dataset.py --species 300 --images-per-species 400
```

- Queries the iNaturalist API for each species (paginates for 400+ images)
- Prioritises hunter-relevant plants: trees, shrubs, berries, toxic plants
- Uses ThreadPoolExecutor (10 workers) for concurrent downloads
- Downloads images into ImageFolder format: `data/plants/train/` + `data/plants/val/`
- Outputs `assets/models/plant_classes.json`

### 2. Metadata generation — `build_plant_metadata.py`

Builds species metadata for Phase 2 reranking:

```bash
python tools/build_plant_metadata.py
```

- Reads `plant_classes.json` for the species list
- Queries iNaturalist for common names, observation months, and taxonomy
- Outputs `assets/models/plant_metadata.json` with region, season, plant part, and toxicity data

### 3. Training — `train_plant_classifier.py`

Trains an EfficientNet-Lite0 classifier:

```bash
python tools/train_plant_classifier.py --epochs 30 --batch-size 32 --label-smoothing 0.1 --mixup-alpha 0.2
```

- Pretrained ImageNet backbone via `timm`
- Input: 224×224 RGB, ImageNet mean/std normalisation
- Augmentation: random crop, rotation, flip, colour jitter, blur, **MixUp** (α=0.2)
- AdamW + cosine LR schedule, cross-entropy with **label smoothing** (0.1)
- Saves best checkpoint to `tools/plant_classifier_best.pt`
- Trained on ~96K train / ~24K val images (299 species, 400 images each)
- Achieved **72.7% top-1 val accuracy** on Apple Silicon MPS

### 4. Export — `export_plant_classifier.py`

Converts the trained model to TFLite:

```bash
# Requires Python 3.12 (onnx2tf is not compatible with 3.13)
tools/.export_venv/bin/python tools/export_plant_classifier.py
```

- Export chain: PyTorch → ONNX (TorchScript) → TF SavedModel (onnx2tf) → TFLite float16
- Must use the legacy TorchScript ONNX exporter (dynamo exporter produces incompatible ops)
- Input: `[1, 224, 224, 3]` NHWC float32
- Output: `[1, num_species]` logits
- Copies to `assets/models/plant_classifier_float16.tflite` (~7.5 MB)

### Output files

```
assets/models/
  plant_classifier_float16.tflite   — ~7.5 MB, EfficientNet-Lite0
  plant_classes.json                — {0: "Acer saccharum", 1: "Quercus alba", ...}
  plant_metadata.json               — species metadata for reranking
```

### Full pipeline

```bash
# 1. Create venvs
python3.13 -m venv tools/.venv          # for training
python3.12 -m venv tools/.export_venv   # for export (onnx2tf needs 3.12)
source tools/.venv/bin/activate
pip install -r tools/requirements.txt

# 2. Download dataset (~1–2 hours for 300 species × 400 images)
python tools/build_plant_dataset.py --species 300 --images-per-species 400

# 3. Build metadata
python tools/build_plant_metadata.py

# 4. Train (~15 hours on Apple Silicon MPS, 30 epochs)
python tools/train_plant_classifier.py --epochs 30 --label-smoothing 0.1 --mixup-alpha 0.2

# 5. Export to TFLite (use Python 3.12 venv)
tools/.export_venv/bin/pip install -r tools/requirements.txt
tools/.export_venv/bin/python tools/export_plant_classifier.py

# 6. (Optional) Delete training data — the model + classes + metadata are all that's needed
rm -rf data/plants/
```

---

# Land Overlay (Public / Crown Land Boundaries)

## Background

Monyx shows a toggleable overlay of **public/Crown land boundaries** on the map, colour-coded by managing agency (federal parks, provincial parks, Crown land, wildlife management areas, etc.). This tells hunters at a glance where they can and cannot hunt — uncoloured areas are private land.

Unlike ML models (which are bundled in the app), the land overlay uses **Mapbox's vector tile infrastructure**. Government geospatial data is converted into a Mapbox vector tileset, uploaded to Mapbox Studio, and served from the Mapbox CDN alongside the satellite/streets base map. This means:

- **No large files bundled in the app binary**
- **Offline support** via Mapbox TileStore (same as offline map regions)
- **Updates** by re-running the pipeline and re-uploading — no app update needed

## How it works

```
Government REST APIs (ArcGIS REST, Socrata SODA)
  ↓  Python requests — query by province, download as GeoJSON
  ↓  Python — normalize attributes to unified schema
  ↓  Merge all sources into single GeoJSON
  ↓  tippecanoe — generate optimized vector tiles (MBTiles)
  ↓  Upload to Mapbox Studio as custom tileset
  ↓  Mapbox CDN serves tiles to the app on demand
  ↓  Flutter app adds VectorSource + FillLayer + LineLayer
```

## Data sources

### Canada

| Source | Coverage | URL | Format |
|--------|----------|-----|--------|
| **CPCAD** (Canadian Protected & Conserved Areas Database) | All provinces — national/provincial parks, WMAs, conservation areas, ecological reserves | [ArcGIS REST API](https://maps-cartes.ec.gc.ca/arcgis/rest/services/CWS_SCF/CPCAD/MapServer/0) / [Open Canada](https://open.canada.ca/data/en/dataset/6c343726-1e92-451a-876a-76e17d398a1c) | ArcGIS REST → GeoJSON |
| **NS Crown Land** | Nova Scotia — unprotected Crown land parcels | [Nova Scotia Open Data](https://data.novascotia.ca/Lands-Forests-and-Wildlife/Crown-Land/3nka-59nz) | GeoJSON |

### US (Phase 5 — not yet implemented)

| Source | Coverage | URL | Format |
|--------|----------|-----|--------|
| **PAD-US** (Protected Areas Database of the US) | All states — federal, state, local public lands | [USGS Science Data Catalog](https://www.sciencebase.gov/catalog/item/652ef534d34ea70453562141) | GeoPackage |

## Unified schema

Every polygon in the merged GeoJSON has these properties:

| Property | Type | Description | Examples |
|----------|------|-------------|----------|
| `country` | string | ISO 2-letter country code | `CA`, `US` |
| `manager` | string | Normalized manager category (drives colour) | `federal_park`, `crown_land`, `wildlife_mgmt` |
| `manager_name` | string | Specific agency name | `Parks Canada`, `Nova Scotia DNR`, `BLM` |
| `name` | string | Area name | `Kejimkujik`, `Cape Breton Highlands` |
| `province_state` | string | Province/state code | `NS`, `ON`, `MT` |
| `source` | string | Dataset origin | `cpcad`, `ns_open_data`, `pad_us` |

### Manager categories (colour coding)

| Category | Colour | Typical source |
|----------|--------|----------------|
| `federal_park` | Brown #B5651D | Parks Canada, NPS |
| `provincial_park` | Dark green #2E7D32 | Provincial parks |
| `crown_land` | Yellow #FBC02D | Provincial Crown land, BLM |
| `wildlife_mgmt` | Olive #827717 | WMAs, NWAs, migratory bird sanctuaries |
| `conservation` | Teal #00897B | Ecological reserves, nature reserves |
| `military` | Red #C62828 | DND, military reserves |
| `blm` | Yellow #FBC02D | US Bureau of Land Management |
| `usfs` | Green #388E3C | US Forest Service |
| `nps` | Brown #B5651D | US National Parks |
| `state_park` | Dark green #2E7D32 | US state parks/forests |

## Prerequisites

```bash
# System tools (macOS)
brew install tippecanoe

# Python dependencies (reuse existing tools venv)
source tools/.venv/bin/activate
pip install -r tools/land_requirements.txt
```

## Run the pipeline

### Proof of concept (Nova Scotia only)

```bash
# 1. Query CPCAD REST API + download NS Crown Land (~160 MB)
python tools/build_land_tileset.py download

# 2. Normalize attributes and merge into unified GeoJSON
python tools/build_land_tileset.py process

# 3. Generate vector tiles (MBTiles)
python tools/build_land_tileset.py tiles

# Or run all three steps:
python tools/build_land_tileset.py all
```

### Output

```
tools/land_data/output/land_overlay.mbtiles   — vector tileset, upload to Mapbox
```

### Upload to Mapbox Studio

1. Go to https://studio.mapbox.com/tilesets/
2. Click **New tileset** → upload `tools/land_data/output/land_overlay.mbtiles`
3. Wait for processing to complete
4. Copy the **tileset ID** (shown on the tileset page, e.g. `yourusername.land_overlay`)
5. Add it to your `.env` file:
   ```
   LAND_TILESET_ID=yourusername.land_overlay
   ```
6. Run the app with `flutter run --dart-define-from-file=.env`

## Adding more provinces

To expand coverage, add new data sources to `build_land_tileset.py`:

1. **Find the provincial Crown Land dataset** (search `<province> Crown Land open data`)
2. Add the download URL and a processing function following the NS pattern
3. The CPCAD REST API already covers protected areas for all provinces — just add the province code to the query:
   ```python
   # Province codes in CPCAD_LOC_CODES dict:
   # AB=1, BC=2, MB=3, NB=4, NL=5, NT=6, NS=7, NU=8, ON=9, PE=10, QC=11, SK=12, YT=13
   data = _query_cpcad_geojson(requests, "NB")  # query New Brunswick
   ```
4. Re-run the pipeline and re-upload the tileset

## Flutter integration

The overlay is implemented in `lib/screens/map/_land_overlay.dart` as an extension on `_MapScreenState` (same pattern as `_hiking.dart`, `_weather.dart`, etc.):

- **VectorSource** → points to the Mapbox tileset (configured via `LAND_TILESET_ID` env var)
- **FillLayer** → semi-transparent fill, colour-coded by `manager` property
- **LineLayer** → boundary outlines
- **Toggle button** → left sidebar, Pro-gated (free users see lock icon)
- **Filter sheet** → long-press or second tap to show/hide specific agency categories

### Key files

| File | Purpose |
|------|---------|
| `lib/screens/map/_land_overlay.dart` | Map overlay mixin (source, layers, UI) |
| `lib/config.dart` | `AppConfig.landTilesetId` — tileset ID from env |
| `tools/build_land_tileset.py` | Data pipeline (download → normalize → tiles) |
| `tools/land_requirements.txt` | Python dependencies for the pipeline |
| `tools/land_data/` | Working directory for raw/processed data (gitignored) |
