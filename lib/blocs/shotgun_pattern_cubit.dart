import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/calibration_record.dart';
import '../models/calibration_session.dart';
import '../models/pattern_result.dart';
import '../models/shotgun_setup.dart';
import '../services/pattern_calibrator.dart';
import '../ballistics/pattern_engine.dart';
import '../services/shotgun_service.dart';

// ── States ───────────────────────────────────────────────────────────

abstract class ShotgunPatternState extends Equatable {
  const ShotgunPatternState();
  @override
  List<Object?> get props => [];
}

class PatternIdle extends ShotgunPatternState {
  const PatternIdle();
}

class PatternComputing extends ShotgunPatternState {
  const PatternComputing();
}

class PatternReady extends ShotgunPatternState {
  final PatternResult result;
  final ShotgunSetup setup;
  final double? shooterLat;
  final double? shooterLon;
  final double? targetLat;
  final double? targetLon;
  final String? lineId;
  const PatternReady(
    this.result, {
    required this.setup,
    this.shooterLat,
    this.shooterLon,
    this.targetLat,
    this.targetLon,
    this.lineId,
  });
  @override
  List<Object?> get props => [
    result,
    setup,
    shooterLat,
    shooterLon,
    targetLat,
    targetLon,
    lineId,
  ];
}

class PatternError extends ShotgunPatternState {
  final String message;
  const PatternError(this.message);
  @override
  List<Object?> get props => [message];
}

// Calibration sub-states
class CalibrationAnalyzing extends ShotgunPatternState {
  const CalibrationAnalyzing();
}

class CalibrationReady extends ShotgunPatternState {
  final CalibrationSession session;
  final PatternResult before;
  final PatternResult after;
  final ShotgunSetup setup;
  final Uint8List rectifiedImage;
  const CalibrationReady({
    required this.session,
    required this.before,
    required this.after,
    required this.setup,
    required this.rectifiedImage,
  });
  @override
  List<Object?> get props => [session, before, after, setup, rectifiedImage];
}

class CalibrationError extends ShotgunPatternState {
  final String message;
  const CalibrationError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Cubit ────────────────────────────────────────────────────────────

class ShotgunPatternCubit extends Cubit<ShotgunPatternState> {
  final PatternEngine _engine;
  final ShotgunService _service;
  final PatternCalibrator _calibrator;

  ShotgunPatternCubit({
    required PatternEngine engine,
    required ShotgunService service,
    PatternCalibrator? calibrator,
  }) : _engine = engine,
       _service = service,
       _calibrator = calibrator ?? PatternCalibrator(),
       super(const PatternIdle());

  /// Predict pattern at a given distance using stored calibration if available.
  Future<void> predict({
    required ShotgunSetup setup,
    required double distanceYards,
    double? shooterLat,
    double? shooterLon,
    double? targetLat,
    double? targetLon,
    String? lineId,
  }) async {
    emit(const PatternComputing());
    try {
      // Build a stable setup key from the profile's unique ID for calibration
      // lookup.
      final setupId = setup.id;
      final calibration = await _service.loadCalibration(setupId);

      final result = _engine.predict(
        setup: setup,
        distanceYards: distanceYards,
        calibration: calibration,
      );

      emit(
        PatternReady(
          result,
          setup: setup,
          shooterLat: shooterLat,
          shooterLon: shooterLon,
          targetLat: targetLat,
          targetLon: targetLon,
          lineId: lineId,
        ),
      );
    } catch (e) {
      emit(PatternError('Pattern prediction failed: $e'));
    }
  }

  /// Analyse a calibration photo and emit before/after prediction comparisons.
  Future<void> analyzePhoto({
    required File imageFile,
    required ShotgunSetup setup,
    required double distanceYards,
    double sheetSizeInches = 24.0,
  }) async {
    emit(const CalibrationAnalyzing());
    try {
      final analysis = await _calibrator.analyze(
        imageFile,
        expectedPelletCount: setup.pelletCount,
        sheetSizeInches: sheetSizeInches,
        distanceYards: distanceYards,
      );

      // "before" = prediction without any calibration
      final before = _engine.predict(
        setup: setup,
        distanceYards: distanceYards,
      );

      // Build a tentative CalibrationRecord from this single session to
      // preview the "after" result, blended with any existing record.
      final setupId = setup.id;
      final existing = await _service.loadCalibration(setupId);
      final tentative = _blendCalibration(
        existing: existing,
        session: analysis.session,
        setup: setup,
        distanceYards: distanceYards,
      );

      final after = _engine.predict(
        setup: setup,
        distanceYards: distanceYards,
        calibration: tentative,
      );

      emit(
        CalibrationReady(
          session: analysis.session,
          before: before,
          after: after,
          setup: setup,
          rectifiedImage: analysis.rectifiedImage,
        ),
      );
    } catch (e) {
      emit(CalibrationError('Calibration failed: $e'));
    }
  }

  /// Accept the most recent calibration and persist it.
  Future<void> acceptCalibration({
    required CalibrationSession session,
    required ShotgunSetup setup,
    required double distanceYards,
  }) async {
    final setupId = setup.id;
    final existing = await _service.loadCalibration(setupId);
    final record = _blendCalibration(
      existing: existing,
      session: session,
      setup: setup,
      distanceYards: distanceYards,
    );

    await _service.saveCalibration(setupId, record);
    await _service.saveSession(setupId, session);

    // Re-predict with the saved calibration
    final result = _engine.predict(
      setup: setup,
      distanceYards: distanceYards,
      calibration: record,
    );
    emit(PatternReady(result, setup: setup));
  }

  /// Blend a new session into an existing calibration record (or create one).
  CalibrationRecord _blendCalibration({
    CalibrationRecord? existing,
    required CalibrationSession session,
    required ShotgunSetup setup,
    required double distanceYards,
  }) {
    final setupId = setup.id;

    // Compute what the uncalibrated engine predicts for this distance
    final baseline = _engine.predict(
      setup: setup,
      distanceYards: session.distanceYards,
    );

    // Ratio of measured to predicted for diameter
    final measuredDiameter = session.measuredR75Inches * 2.0;
    final diamRatio = baseline.spreadDiameterInches > 0
        ? measuredDiameter / baseline.spreadDiameterInches
        : 1.0;

    // Ratio for sigma (R50)
    final sigRatio = baseline.r50Inches > 0
        ? session.measuredR50Inches / baseline.r50Inches
        : 1.0;

    if (existing == null) {
      return CalibrationRecord(
        setupId: setupId,
        diameterMultiplier: diamRatio,
        sigmaMultiplier: sigRatio,
        poiOffsetXInches: session.poiOffsetXInches,
        poiOffsetYInches: session.poiOffsetYInches,
        sampleCount: 1,
        aggregateConfidence: session.sessionConfidence,
      );
    }

    // Exponential moving average — new samples weighted by confidence
    final n = existing.sampleCount + 1;
    final w = session.sessionConfidence.clamp(0.1, 1.0);
    final oldW = 1.0 - w / n;
    final newW = w / n;

    return CalibrationRecord(
      setupId: setupId,
      diameterMultiplier: existing.diameterMultiplier * oldW + diamRatio * newW,
      sigmaMultiplier: existing.sigmaMultiplier * oldW + sigRatio * newW,
      poiOffsetXInches:
          existing.poiOffsetXInches * oldW + session.poiOffsetXInches * newW,
      poiOffsetYInches:
          existing.poiOffsetYInches * oldW + session.poiOffsetYInches * newW,
      sampleCount: n,
      aggregateConfidence: min(
        1.0,
        existing.aggregateConfidence + session.sessionConfidence * 0.1,
      ),
    );
  }

  /// Preview what the calibrated result would look like for an edited session
  /// without persisting anything. Returns the "after" [PatternResult].
  Future<PatternResult> previewCalibration({
    required CalibrationSession session,
    required ShotgunSetup setup,
    required double distanceYards,
  }) async {
    final existing = await _service.loadCalibration(setup.id);
    final tentative = _blendCalibration(
      existing: existing,
      session: session,
      setup: setup,
      distanceYards: distanceYards,
    );
    return _engine.predict(
      setup: setup,
      distanceYards: distanceYards,
      calibration: tentative,
    );
  }

  void clear() => emit(const PatternIdle());

  /// Re-show a previously computed pattern (e.g. when tapping a saved line).
  /// Re-predicts using stored calibration so post-calibration results are
  /// reflected even if the original cached result was uncalibrated.
  Future<void> show(
    PatternResult result, {
    required ShotgunSetup setup,
    double? shooterLat,
    double? shooterLon,
    double? targetLat,
    double? targetLon,
    String? lineId,
  }) async {
    final calibration = await _service.loadCalibration(setup.id);
    final fresh = calibration != null
        ? _engine.predict(
            setup: setup,
            distanceYards: result.distanceYards,
            calibration: calibration,
          )
        : result;

    emit(
      PatternReady(
        fresh,
        setup: setup,
        shooterLat: shooterLat,
        shooterLon: shooterLon,
        targetLat: targetLat,
        targetLon: targetLon,
        lineId: lineId,
      ),
    );
  }
}
