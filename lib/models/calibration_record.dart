import 'package:equatable/equatable.dart';

class CalibrationRecord extends Equatable {
  final String setupId;
  final double diameterMultiplier;
  final double sigmaMultiplier;
  final double poiOffsetXInches;
  final double poiOffsetYInches;
  final int sampleCount;
  final double aggregateConfidence;

  // Reserved for future elliptical pattern modeling
  final double? ellipseRatio;
  final double? ellipseAngleDeg;

  const CalibrationRecord({
    required this.setupId,
    required this.diameterMultiplier,
    required this.sigmaMultiplier,
    required this.poiOffsetXInches,
    required this.poiOffsetYInches,
    required this.sampleCount,
    required this.aggregateConfidence,
    this.ellipseRatio,
    this.ellipseAngleDeg,
  });

  Map<String, dynamic> toJson() => {
    'setupId': setupId,
    'diameterMultiplier': diameterMultiplier,
    'sigmaMultiplier': sigmaMultiplier,
    'poiOffsetXInches': poiOffsetXInches,
    'poiOffsetYInches': poiOffsetYInches,
    'sampleCount': sampleCount,
    'aggregateConfidence': aggregateConfidence,
    if (ellipseRatio != null) 'ellipseRatio': ellipseRatio,
    if (ellipseAngleDeg != null) 'ellipseAngleDeg': ellipseAngleDeg,
  };

  factory CalibrationRecord.fromJson(Map<String, dynamic> json) =>
      CalibrationRecord(
        setupId: json['setupId'] as String,
        diameterMultiplier: (json['diameterMultiplier'] as num).toDouble(),
        sigmaMultiplier: (json['sigmaMultiplier'] as num).toDouble(),
        poiOffsetXInches: (json['poiOffsetXInches'] as num).toDouble(),
        poiOffsetYInches: (json['poiOffsetYInches'] as num).toDouble(),
        sampleCount: (json['sampleCount'] as num).toInt(),
        aggregateConfidence: (json['aggregateConfidence'] as num).toDouble(),
        ellipseRatio: json['ellipseRatio'] != null
            ? (json['ellipseRatio'] as num).toDouble()
            : null,
        ellipseAngleDeg: json['ellipseAngleDeg'] != null
            ? (json['ellipseAngleDeg'] as num).toDouble()
            : null,
      );

  @override
  List<Object?> get props => [
    setupId,
    diameterMultiplier,
    sigmaMultiplier,
    poiOffsetXInches,
    poiOffsetYInches,
    sampleCount,
    aggregateConfidence,
    ellipseRatio,
    ellipseAngleDeg,
  ];
}
