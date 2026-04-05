import 'package:equatable/equatable.dart';

class PatternResult extends Equatable {
  final double distanceYards;
  final double spreadDiameterInches;
  final double r50Inches;
  final double r75Inches;
  final int pelletsIn10Circle;
  final int pelletsIn20Circle;
  final double poiOffsetXInches;
  final double poiOffsetYInches;
  final bool isCalibrated;
  final int totalPellets;
  final double patternEfficiency;

  const PatternResult({
    required this.distanceYards,
    required this.spreadDiameterInches,
    required this.r50Inches,
    required this.r75Inches,
    required this.pelletsIn10Circle,
    required this.pelletsIn20Circle,
    required this.poiOffsetXInches,
    required this.poiOffsetYInches,
    required this.isCalibrated,
    required this.totalPellets,
    this.patternEfficiency = 0.0,
  });

  @override
  List<Object?> get props => [
    distanceYards,
    spreadDiameterInches,
    r50Inches,
    r75Inches,
    pelletsIn10Circle,
    pelletsIn20Circle,
    poiOffsetXInches,
    poiOffsetYInches,
    isCalibrated,
    totalPellets,
    patternEfficiency,
  ];
}
