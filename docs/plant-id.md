# Plant Identification

Pro subscribers can identify plant species from photos — entirely on-device, no internet required. Supports US and Canada species.

## How it works

1. Tap the **🌿 button** on the map screen (Pro only).
2. Choose the plant part: **Leaf** 🍃, **Flower** 🌸, **Bark** 🌳, **Fruit** 🍎, or **Whole Plant** 🌿.
3. Take a photo or choose one from gallery.
4. Atlix Hunt runs an EfficientNet-Lite0 classifier on-device.
5. Results are **reranked** using your GPS location (US state / Canadian province), current month, and selected plant part.
6. A **results page** shows the photo and a ranked list of species predictions with confidence scores, common names, and scientific names.
7. Results can be **saved** and **retrieved** later.

## Model

| Model | Species | Input       | Size     | Architecture       |
| ----- | ------- | ----------- | -------- | ------------------ |
| Plant | 200–500 | 224×224 RGB | ~5–15 MB | EfficientNet-Lite0 |

The model is trained on iNaturalist research-grade observations filtered to US + Canada plants. See [tools/README.md](tools/README.md) for the full training and export pipeline.

## Phase 2: Metadata Reranking

Raw classifier predictions are reranked using bundled species metadata:

- **Region**: species present in user's state/province get a 1.5× boost; absent species get 0.2×
- **Season**: species visible in the current month get 1.3×; off-season species get 0.5×
- **Plant part**: species with strong identifiers for the selected part get 1.2×

Formula: `finalScore = modelScore × regionWeight × seasonWeight × partWeight`

Region lookup is fully offline — uses a bundled US state / Canadian province bounding-box table.

## Architecture

| Component   | File                                   | Role                                                         |
| ----------- | -------------------------------------- | ------------------------------------------------------------ |
| Classifier  | `lib/services/plant_classifier.dart`   | Loads TFLite model, runs classification, returns predictions |
| Reranker    | `lib/services/plant_reranker.dart`     | Metadata-based reranking (region, season, plant part)        |
| Region      | `lib/services/region_lookup.dart`      | Offline GPS → US state / CA province resolver                |
| Persistence | `lib/services/plant_service.dart`      | Saves/loads plant results + images via Hive                  |
| State       | `lib/blocs/plant_cubit.dart`           | Manages capture → classify → rerank → save flow              |
| Results UI  | `lib/screens/plant_result_screen.dart` | Photo + ranked species list with confidence bars             |
| Saved list  | `lib/screens/saved_plants_screen.dart` | Browse and revisit past identifications                      |
| Metadata    | `lib/models/plant_metadata.dart`       | Species metadata model (regions, months, parts, toxicity)    |
