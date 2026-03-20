import 'package:equatable/equatable.dart';
import 'weather_data.dart';

class ShotSolution extends Equatable {
  final double rangeYards;
  final double shotAngleDeg;

  // Elevation correction (positive = bullet hits HIGH, shooter dials UP)
  final double dropInches;
  final double dropMoa;
  final int dropClicks;

  // Wind correction (positive = bullet drifts RIGHT, shooter dials LEFT)
  final double windDriftInches;
  final double windDriftMoa;
  final int windDriftClicks;

  // Extra info
  final double velocityAtTargetFps;
  final double energyAtTargetFtLbs;
  final double timeOfFlightSec;
  final double densityAltitudeFt;

  final WeatherSource weatherSource;
  final double headwindMph;
  final double crosswindMph; // positive = from left

  const ShotSolution({
    required this.rangeYards,
    required this.shotAngleDeg,
    required this.dropInches,
    required this.dropMoa,
    required this.dropClicks,
    required this.windDriftInches,
    required this.windDriftMoa,
    required this.windDriftClicks,
    required this.velocityAtTargetFps,
    required this.energyAtTargetFtLbs,
    required this.timeOfFlightSec,
    required this.densityAltitudeFt,
    required this.weatherSource,
    required this.headwindMph,
    required this.crosswindMph,
  });

  /// Direction label for elevation
  String get elevationDirection => dropInches < 0 ? 'UP' : 'DOWN';

  /// Direction label for wind
  String get windDirection {
    if (windDriftInches.abs() < 0.05) return '';
    return windDriftInches > 0 ? 'LEFT' : 'RIGHT';
  }

  @override
  List<Object?> get props => [
    rangeYards,
    shotAngleDeg,
    dropInches,
    dropMoa,
    dropClicks,
    windDriftInches,
    windDriftMoa,
    windDriftClicks,
    velocityAtTargetFps,
    energyAtTargetFtLbs,
    timeOfFlightSec,
    densityAltitudeFt,
    weatherSource,
  ];
}
