import 'shot_solution.dart';
import 'pattern_result.dart';
import 'weather_data.dart';

enum SavedLineType { rifle, shotgun }

class SavedLine {
  final String id;
  final SavedLineType type;
  final String profileId;
  final double shooterLat;
  final double shooterLon;
  final double targetLat;
  final double targetLon;
  final ShotSolution? solution;
  final PatternResult? pattern;
  final DateTime createdAt;

  SavedLine({
    required this.id,
    required this.type,
    required this.profileId,
    required this.shooterLat,
    required this.shooterLon,
    required this.targetLat,
    required this.targetLon,
    this.solution,
    this.pattern,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'profileId': profileId,
    'shooterLat': shooterLat,
    'shooterLon': shooterLon,
    'targetLat': targetLat,
    'targetLon': targetLon,
    if (solution != null) 'solution': _solutionToJson(solution!),
    if (pattern != null) 'pattern': _patternToJson(pattern!),
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedLine.fromJson(Map<String, dynamic> j) => SavedLine(
    id: j['id'] as String,
    type: SavedLineType.values.byName(j['type'] as String),
    profileId: j['profileId'] as String,
    shooterLat: (j['shooterLat'] as num).toDouble(),
    shooterLon: (j['shooterLon'] as num).toDouble(),
    targetLat: (j['targetLat'] as num).toDouble(),
    targetLon: (j['targetLon'] as num).toDouble(),
    solution: j['solution'] != null
        ? _solutionFromJson(j['solution'] as Map<String, dynamic>)
        : null,
    pattern: j['pattern'] != null
        ? _patternFromJson(j['pattern'] as Map<String, dynamic>)
        : null,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );

  static Map<String, dynamic> _solutionToJson(ShotSolution s) => {
    'rangeYards': s.rangeYards,
    'shotAngleDeg': s.shotAngleDeg,
    'dropInches': s.dropInches,
    'dropMoa': s.dropMoa,
    'dropClicks': s.dropClicks,
    'windDriftInches': s.windDriftInches,
    'windDriftMoa': s.windDriftMoa,
    'windDriftClicks': s.windDriftClicks,
    'velocityAtTargetFps': s.velocityAtTargetFps,
    'energyAtTargetFtLbs': s.energyAtTargetFtLbs,
    'timeOfFlightSec': s.timeOfFlightSec,
    'densityAltitudeFt': s.densityAltitudeFt,
    'weatherSource': s.weatherSource.name,
    'headwindMph': s.headwindMph,
    'crosswindMph': s.crosswindMph,
  };

  static ShotSolution _solutionFromJson(Map<String, dynamic> j) => ShotSolution(
    rangeYards: (j['rangeYards'] as num).toDouble(),
    shotAngleDeg: (j['shotAngleDeg'] as num).toDouble(),
    dropInches: (j['dropInches'] as num).toDouble(),
    dropMoa: (j['dropMoa'] as num).toDouble(),
    dropClicks: (j['dropClicks'] as num).toInt(),
    windDriftInches: (j['windDriftInches'] as num).toDouble(),
    windDriftMoa: (j['windDriftMoa'] as num).toDouble(),
    windDriftClicks: (j['windDriftClicks'] as num).toInt(),
    velocityAtTargetFps: (j['velocityAtTargetFps'] as num).toDouble(),
    energyAtTargetFtLbs: (j['energyAtTargetFtLbs'] as num).toDouble(),
    timeOfFlightSec: (j['timeOfFlightSec'] as num).toDouble(),
    densityAltitudeFt: (j['densityAltitudeFt'] as num).toDouble(),
    weatherSource: WeatherSource.values.byName(j['weatherSource'] as String),
    headwindMph: (j['headwindMph'] as num).toDouble(),
    crosswindMph: (j['crosswindMph'] as num).toDouble(),
  );

  static Map<String, dynamic> _patternToJson(PatternResult p) => {
    'distanceYards': p.distanceYards,
    'spreadDiameterInches': p.spreadDiameterInches,
    'r50Inches': p.r50Inches,
    'r75Inches': p.r75Inches,
    'pelletsIn10Circle': p.pelletsIn10Circle,
    'pelletsIn20Circle': p.pelletsIn20Circle,
    'poiOffsetXInches': p.poiOffsetXInches,
    'poiOffsetYInches': p.poiOffsetYInches,
    'isCalibrated': p.isCalibrated,
    'totalPellets': p.totalPellets,
  };

  static PatternResult _patternFromJson(Map<String, dynamic> j) =>
      PatternResult(
        distanceYards: (j['distanceYards'] as num).toDouble(),
        spreadDiameterInches: (j['spreadDiameterInches'] as num).toDouble(),
        r50Inches: (j['r50Inches'] as num).toDouble(),
        r75Inches: (j['r75Inches'] as num).toDouble(),
        pelletsIn10Circle: (j['pelletsIn10Circle'] as num).toInt(),
        pelletsIn20Circle: (j['pelletsIn20Circle'] as num).toInt(),
        poiOffsetXInches: (j['poiOffsetXInches'] as num).toDouble(),
        poiOffsetYInches: (j['poiOffsetYInches'] as num).toDouble(),
        isCalibrated: j['isCalibrated'] as bool,
        totalPellets: (j['totalPellets'] as num).toInt(),
      );
}
