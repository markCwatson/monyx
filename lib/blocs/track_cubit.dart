import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/track_result.dart';
import '../services/track_detector.dart';
import '../services/track_service.dart';

// ── States ──────────────────────────────────────────────────────────────

abstract class TrackState extends Equatable {
  const TrackState();
  @override
  List<Object?> get props => [];
}

class TrackIdle extends TrackState {
  const TrackIdle();
}

class TrackDetecting extends TrackState {
  const TrackDetecting();
}

class TrackDone extends TrackState {
  final TrackResult result;
  final bool saved;
  const TrackDone(this.result, {this.saved = false});
  @override
  List<Object?> get props => [result, saved];
}

class TrackError extends TrackState {
  final String message;
  const TrackError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ───────────────────────────────────────────────────────────────

class TrackCubit extends Cubit<TrackState> {
  final TrackDetector _detector;
  final TrackService _service;
  final ImagePicker _picker;
  static const _uuid = Uuid();

  TrackCubit({
    required TrackDetector detector,
    required TrackService service,
    ImagePicker? picker,
  }) : _detector = detector,
       _service = service,
       _picker = picker ?? ImagePicker(),
       super(const TrackIdle());

  /// Pick or capture a photo, then run detection.
  Future<void> capture(
    TraceType traceType, {
    ImageSource source = ImageSource.camera,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1920,
      );
      if (photo == null) return; // user cancelled

      emit(const TrackDetecting());

      // Initialise detector for this trace type
      await _detector.init(traceType);

      // Get image dimensions
      final file = File(photo.path);
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        emit(const TrackError('Could not decode image'));
        return;
      }

      // Run inference
      final detections = await _detector.detect(file);

      final result = TrackResult(
        id: _uuid.v4(),
        imagePath: photo.path,
        traceType: traceType,
        detections: detections,
        timestamp: DateTime.now(),
        imageWidth: decoded.width,
        imageHeight: decoded.height,
        latitude: latitude,
        longitude: longitude,
      );

      debugPrint(
        '[TrackCubit] emitting TrackDone: ${result.detections.length} detections, image=${result.imageWidth}x${result.imageHeight}, path=${result.imagePath}',
      );
      emit(TrackDone(result));
    } catch (e) {
      emit(TrackError('Detection failed: $e'));
    }
  }

  /// Save the current result to local storage.
  Future<void> saveResult() async {
    final current = state;
    debugPrint('[TrackCubit] saveResult called, state=$current');
    if (current is! TrackDone) return;

    try {
      final saved = await _service.saveResult(current.result);
      debugPrint(
        '[TrackCubit] save succeeded, new imagePath=${saved.imagePath}',
      );
      emit(TrackDone(saved, saved: true));
    } catch (e) {
      debugPrint('[TrackCubit] save FAILED: $e');
      emit(TrackError('Save failed: $e'));
    }
  }

  /// Reset to idle.
  void clear() => emit(const TrackIdle());

  /// Load saved results list.
  Future<List<TrackResult>> loadSaved() => _service.loadResults();

  /// Delete a saved result.
  Future<void> deleteSaved(String id) => _service.deleteResult(id);
}
