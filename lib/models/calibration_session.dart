import 'dart:math';
import 'dart:ui';

import 'package:equatable/equatable.dart';

class CalibrationSession extends Equatable {
  final double distanceYards;
  final double sheetSizeInches;
  final int detectedPelletCount;
  final double measuredR50Inches;
  final double measuredR75Inches;
  final int pelletsIn10Circle;
  final int pelletsIn20Circle;
  final double poiOffsetXInches;
  final double poiOffsetYInches;
  final double clippingLikelihood;
  final double sessionConfidence;
  final DateTime timestamp;
  final List<Offset> pelletCoordinates; // inches relative to page center

  const CalibrationSession({
    required this.distanceYards,
    this.sheetSizeInches = 24.0,
    required this.detectedPelletCount,
    required this.measuredR50Inches,
    required this.measuredR75Inches,
    required this.pelletsIn10Circle,
    required this.pelletsIn20Circle,
    required this.poiOffsetXInches,
    required this.poiOffsetYInches,
    required this.clippingLikelihood,
    required this.sessionConfidence,
    required this.timestamp,
    required this.pelletCoordinates,
  });

  /// Build a new session with the given [pellets], recomputing all metrics.
  CalibrationSession copyWithPellets(
    List<Offset> pellets,
    int expectedPelletCount,
  ) {
    if (pellets.isEmpty) {
      return CalibrationSession(
        distanceYards: distanceYards,
        sheetSizeInches: sheetSizeInches,
        detectedPelletCount: 0,
        measuredR50Inches: 0,
        measuredR75Inches: 0,
        pelletsIn10Circle: 0,
        pelletsIn20Circle: 0,
        poiOffsetXInches: 0,
        poiOffsetYInches: 0,
        clippingLikelihood: 0,
        sessionConfidence: 0,
        timestamp: timestamp,
        pelletCoordinates: const [],
      );
    }

    final meanX =
        pellets.map((p) => p.dx).reduce((a, b) => a + b) / pellets.length;
    final meanY =
        pellets.map((p) => p.dy).reduce((a, b) => a + b) / pellets.length;

    final distances =
        pellets
            .map((p) => sqrt(pow(p.dx - meanX, 2) + pow(p.dy - meanY, 2)))
            .toList()
          ..sort();

    final i50 = (distances.length * 0.50).ceil().clamp(1, distances.length) - 1;
    final r50 = distances[i50];

    final i75 = (distances.length * 0.75).ceil().clamp(1, distances.length) - 1;
    final r75 = distances[i75];

    final in10 = pellets
        .where((p) => sqrt(pow(p.dx - meanX, 2) + pow(p.dy - meanY, 2)) <= 5.0)
        .length;
    final in20 = pellets
        .where((p) => sqrt(pow(p.dx - meanX, 2) + pow(p.dy - meanY, 2)) <= 10.0)
        .length;

    final halfSheet = sheetSizeInches / 2;
    final nearEdge = pellets
        .where(
          (p) =>
              p.dx.abs() > (halfSheet - 1.0) || p.dy.abs() > (halfSheet - 1.0),
        )
        .length;
    final clipping = (nearEdge / pellets.length).clamp(0.0, 1.0);

    final countRatio = (pellets.length / expectedPelletCount).clamp(0.0, 1.0);
    final confidence = (countRatio * (1.0 - clipping * 0.5)).clamp(0.0, 1.0);

    return CalibrationSession(
      distanceYards: distanceYards,
      sheetSizeInches: sheetSizeInches,
      detectedPelletCount: pellets.length,
      measuredR50Inches: r50,
      measuredR75Inches: r75,
      pelletsIn10Circle: in10,
      pelletsIn20Circle: in20,
      poiOffsetXInches: meanX,
      poiOffsetYInches: meanY,
      clippingLikelihood: clipping,
      sessionConfidence: confidence,
      timestamp: timestamp,
      pelletCoordinates: pellets,
    );
  }

  Map<String, dynamic> toJson() => {
    'distanceYards': distanceYards,
    'sheetSizeInches': sheetSizeInches,
    'detectedPelletCount': detectedPelletCount,
    'measuredR50Inches': measuredR50Inches,
    'measuredR75Inches': measuredR75Inches,
    'pelletsIn10Circle': pelletsIn10Circle,
    'pelletsIn20Circle': pelletsIn20Circle,
    'poiOffsetXInches': poiOffsetXInches,
    'poiOffsetYInches': poiOffsetYInches,
    'clippingLikelihood': clippingLikelihood,
    'sessionConfidence': sessionConfidence,
    'timestamp': timestamp.toIso8601String(),
    'pelletCoordinates': pelletCoordinates.map((o) => [o.dx, o.dy]).toList(),
  };

  factory CalibrationSession.fromJson(Map<String, dynamic> json) {
    final coords = (json['pelletCoordinates'] as List)
        .map((e) => Offset((e[0] as num).toDouble(), (e[1] as num).toDouble()))
        .toList();
    return CalibrationSession(
      distanceYards: (json['distanceYards'] as num).toDouble(),
      sheetSizeInches: (json['sheetSizeInches'] as num?)?.toDouble() ?? 24.0,
      detectedPelletCount: (json['detectedPelletCount'] as num).toInt(),
      measuredR50Inches: (json['measuredR50Inches'] as num).toDouble(),
      measuredR75Inches: (json['measuredR75Inches'] as num).toDouble(),
      pelletsIn10Circle: (json['pelletsIn10Circle'] as num).toInt(),
      pelletsIn20Circle: (json['pelletsIn20Circle'] as num).toInt(),
      poiOffsetXInches: (json['poiOffsetXInches'] as num).toDouble(),
      poiOffsetYInches: (json['poiOffsetYInches'] as num).toDouble(),
      clippingLikelihood: (json['clippingLikelihood'] as num).toDouble(),
      sessionConfidence: (json['sessionConfidence'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      pelletCoordinates: coords,
    );
  }

  @override
  List<Object?> get props => [
    distanceYards,
    sheetSizeInches,
    detectedPelletCount,
    measuredR50Inches,
    measuredR75Inches,
    pelletsIn10Circle,
    pelletsIn20Circle,
    poiOffsetXInches,
    poiOffsetYInches,
    clippingLikelihood,
    sessionConfidence,
    timestamp,
    pelletCoordinates,
  ];
}
