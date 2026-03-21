import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/detection.dart';
import '../models/track_result.dart';

/// On-device YOLOv11 object detector using TFLite.
///
/// Loads the appropriate model (footprint or feces) and runs inference
/// entirely on-device with no internet required.
class TrackDetector {
  static const int _inputSize = 640;
  static const double _confThreshold = 0.25;
  static const double _iouThreshold = 0.45;

  Interpreter? _interpreter;
  Map<int, String>? _classNames;
  int _numClasses = 0;

  /// Initialise the detector for the given trace type.
  Future<void> init(TraceType traceType) async {
    dispose();

    final modelAsset = switch (traceType) {
      TraceType.footprint => 'assets/models/footprint_det_float16.tflite',
      TraceType.feces => 'assets/models/feces_det_float16.tflite',
    };
    final classAsset = switch (traceType) {
      TraceType.footprint => 'assets/models/footprint_classes.json',
      TraceType.feces => 'assets/models/feces_classes.json',
    };

    _interpreter = await Interpreter.fromAsset(modelAsset);

    final classJson = await rootBundle.loadString(classAsset);
    final raw = jsonDecode(classJson) as Map<String, dynamic>;
    _classNames = raw.map((k, v) => MapEntry(int.parse(k), v as String));
    _numClasses = _classNames!.length;
  }

  /// Run detection on an image file.
  ///
  /// Returns detections sorted by confidence (highest first).
  Future<List<Detection>> detect(File imageFile) async {
    if (_interpreter == null || _classNames == null) {
      throw StateError('TrackDetector not initialised — call init() first');
    }

    // Load and decode image
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) throw ArgumentError('Could not decode image');

    final origW = image.width;
    final origH = image.height;

    // Resize to model input size (letterbox preserving aspect ratio)
    final resized = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Convert to float32 tensor [1, 640, 640, 3] normalised to [0, 1] (NHWC)
    final input = _imageToTensor(resized);

    // Allocate output: YOLOv11 detection output is [1, 4+numClasses, numBoxes]
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    // outputShape is typically [1, 4+numClasses, 8400]
    final numPreds = outputShape[2]; // 8400
    final predSize = outputShape[1]; // 4 + numClasses

    final output = List.generate(
      1,
      (_) => List.generate(predSize, (_) => List.filled(numPreds, 0.0)),
    );

    _interpreter!.run(input, output);

    debugPrint(
      '[TrackDetector] Model ran. outputShape=$outputShape, predSize=$predSize, numPreds=$numPreds',
    );

    // Parse and filter detections
    final rawDetections = _parseOutput(
      output[0],
      predSize,
      numPreds,
      origW,
      origH,
    );
    debugPrint(
      '[TrackDetector] Raw detections (pre-NMS): ${rawDetections.length}',
    );
    final nmsDetections = _nms(rawDetections);
    debugPrint('[TrackDetector] NMS detections: ${nmsDetections.length}');
    for (final d in nmsDetections) {
      debugPrint(
        '[TrackDetector]   ${d.className} ${(d.confidence * 100).toStringAsFixed(1)}% box=(${d.x1.toInt()},${d.y1.toInt()},${d.x2.toInt()},${d.y2.toInt()}) origImage=${origW}x$origH',
      );
    }

    return nmsDetections;
  }

  /// Release resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _classNames = null;
  }

  // ── Private helpers ──────────────────────────────────────────────────

  /// Convert image to [1, 640, 640, 3] float32 tensor (NHWC format).
  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    final tensor = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (_) => List.generate(_inputSize, (_) => List.filled(3, 0.0)),
      ),
    );

    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);
        tensor[0][y][x][0] = pixel.r / 255.0;
        tensor[0][y][x][1] = pixel.g / 255.0;
        tensor[0][y][x][2] = pixel.b / 255.0;
      }
    }

    return tensor;
  }

  /// Parse YOLOv11 output tensor [predSize, numBoxes] → list of Detection.
  ///
  /// Output format per column: [cx, cy, w, h, cls0_conf, cls1_conf, ...]
  List<Detection> _parseOutput(
    List<List<double>> output,
    int predSize,
    int numBoxes,
    int origW,
    int origH,
  ) {
    final detections = <Detection>[];

    for (int i = 0; i < numBoxes; i++) {
      // Find best class
      double maxConf = 0;
      int bestClass = 0;
      for (int c = 0; c < _numClasses; c++) {
        final conf = output[4 + c][i];
        if (conf > maxConf) {
          maxConf = conf;
          bestClass = c;
        }
      }

      if (maxConf < _confThreshold) continue;

      // Extract box (cx, cy, w, h) in model coords → (x1, y1, x2, y2) in image coords
      final cx = output[0][i];
      final cy = output[1][i];
      final w = output[2][i];
      final h = output[3][i];

      debugPrint(
        '[TrackDetector] Detection $i: raw cx=$cx cy=$cy w=$w h=$h conf=$maxConf class=$bestClass',
      );

      // Bbox coords are normalised (0–1). Scale directly to original image.
      final x1 = (cx - w / 2) * origW;
      final y1 = (cy - h / 2) * origH;
      final x2 = (cx + w / 2) * origW;
      final y2 = (cy + h / 2) * origH;

      detections.add(
        Detection(
          x1: x1.clamp(0, origW.toDouble()),
          y1: y1.clamp(0, origH.toDouble()),
          x2: x2.clamp(0, origW.toDouble()),
          y2: y2.clamp(0, origH.toDouble()),
          className: _classNames![bestClass] ?? 'unknown',
          confidence: maxConf,
        ),
      );
    }

    // Sort by confidence descending
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    return detections;
  }

  /// Non-maximum suppression: remove overlapping boxes.
  List<Detection> _nms(List<Detection> detections) {
    final kept = <Detection>[];

    for (final det in detections) {
      bool suppressed = false;
      for (final k in kept) {
        if (_iou(det, k) > _iouThreshold) {
          suppressed = true;
          break;
        }
      }
      if (!suppressed) kept.add(det);
    }

    return kept;
  }

  /// Intersection over Union between two detections.
  double _iou(Detection a, Detection b) {
    final x1 = max(a.x1, b.x1);
    final y1 = max(a.y1, b.y1);
    final x2 = min(a.x2, b.x2);
    final y2 = min(a.y2, b.y2);

    final intersection = max(0.0, x2 - x1) * max(0.0, y2 - y1);
    if (intersection == 0) return 0;

    final areaA = (a.x2 - a.x1) * (a.y2 - a.y1);
    final areaB = (b.x2 - b.x1) * (b.y2 - b.y1);

    return intersection / (areaA + areaB - intersection);
  }
}
