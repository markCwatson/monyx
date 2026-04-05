# Animal Track Identification

Pro subscribers can identify animal species from photos of tracks (footprints and scat) directly on-device — no internet required.

## How it works

1. Tap the **paw-print button** on the map screen (Pro only — free users see a locked icon with an upgrade prompt).
2. Choose the trace type: **Footprint** 🐾 or **Scat** 💩.
3. The camera opens — photograph the track.
4. Atlix Hunt runs a YOLOv11 object-detection model on-device to identify the species.
5. A **full-screen results page** shows the photo with bounding boxes drawn over detected tracks, plus a ranked list of species predictions with confidence scores.
6. Results can be **saved** to local storage and **retrieved** later from the saved tracks list.

## Models

The feature uses [AnimalClue](https://dahlian00.github.io/AnimalCluePage/) (ICCV 2025) YOLOv11n models, converted to TFLite for on-device inference:

| Model     | Species | Input       | Size   | Source                                                                          |
| --------- | ------- | ----------- | ------ | ------------------------------------------------------------------------------- |
| Footprint | 117     | 640×640 RGB | ~10 MB | [risashinoda/footprint_yolo](https://huggingface.co/risashinoda/footprint_yolo) |
| Feces     | 101     | 640×640 RGB | ~10 MB | [risashinoda/feces_yolo](https://huggingface.co/risashinoda/feces_yolo)         |

Both models are bundled in the app binary under `assets/models/`. Total added size is ~20 MB.

## Inference pipeline

1. **Capture** — `image_picker` opens the camera and returns a JPEG.
2. **Preprocess** — Image is resized to 640×640 and converted to a float32 NHWC tensor `[1, 640, 640, 3]` with pixel values normalised to `[0, 1]`.
3. **Infer** — `tflite_flutter` runs the model, producing `[1, C, 8400]` where `C = 4 + num_classes`.
4. **Post-process** — Confidence thresholding (0.25), coordinate scaling back to original image dimensions, and Non-Maximum Suppression (IoU 0.45) to remove duplicate boxes.
5. **Display** — Bounding boxes are drawn on the photo with colour-coded confidence (green ≥70%, amber ≥40%, red below). Species names and confidence percentages are shown.

## Model export

The TFLite models are generated from the original PyTorch weights using a Python pipeline in `tools/`. See [tools/README.md](tools/README.md) for full reproduction instructions.

```bash
python3 -m venv tools/.venv
source tools/.venv/bin/activate
pip install -r tools/requirements.txt
python tools/export_models.py
```

## Architecture

| Component   | File                                       | Role                                                         |
| ----------- | ------------------------------------------ | ------------------------------------------------------------ |
| Detector    | `lib/services/track_detector.dart`         | Loads TFLite model, runs inference, returns `Detection` list |
| Persistence | `lib/services/track_service.dart`          | Saves/loads track results + images via Hive                  |
| State       | `lib/blocs/track_cubit.dart`               | Manages capture → detect → save flow                         |
| Results UI  | `lib/screens/track_result_screen.dart`     | Annotated image + ranked species list                        |
| Saved list  | `lib/screens/saved_tracks_screen.dart`     | Browse and revisit past identifications                      |
| Overlay     | `lib/widgets/detection_image_painter.dart` | Draws bounding boxes on the photo                            |
