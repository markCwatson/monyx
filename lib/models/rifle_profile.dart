import 'package:equatable/equatable.dart';

enum DragModel { g1, g7 }

// Equatable is critical for the BLoC pattern — the cubit won't re-emit
//... state if the new value equals the old one.
class RifleProfile extends Equatable {
  final String name;
  final String caliber;
  final double barrelLengthInches;
  final double twistRateInches; // 1:X twist
  final double sightHeightInches;
  final double zeroDistanceYards;
  final double clickValueMoa; // MOA per click
  final double muzzleVelocityFps;
  final double bulletWeightGrains;
  final double ballisticCoefficient;
  final DragModel dragModel;

  const RifleProfile({
    required this.name,
    required this.caliber,
    required this.barrelLengthInches,
    required this.twistRateInches,
    required this.sightHeightInches,
    required this.zeroDistanceYards,
    required this.clickValueMoa,
    required this.muzzleVelocityFps,
    required this.bulletWeightGrains,
    required this.ballisticCoefficient,
    required this.dragModel,
  });

  /// Sensible default: .308 Win 175gr SMK
  factory RifleProfile.default308() => const RifleProfile(
    name: 'Tikka T3X Varmint - Federal 175 Matchking',
    caliber: '.308 Win',
    barrelLengthInches: 24,
    twistRateInches: 11,
    sightHeightInches: 1.75,
    zeroDistanceYards: 100,
    clickValueMoa: 0.25,
    muzzleVelocityFps: 2642,
    bulletWeightGrains: 175,
    ballisticCoefficient: 0.224,
    dragModel: DragModel.g7,
  );

  // Hive stores raw JSON, so model must convert to/from Map<String, dynamic>
  Map<String, dynamic> toJson() => {
    'name': name,
    'caliber': caliber,
    'barrelLengthInches': barrelLengthInches,
    'twistRateInches': twistRateInches,
    'sightHeightInches': sightHeightInches,
    'zeroDistanceYards': zeroDistanceYards,
    'clickValueMoa': clickValueMoa,
    'muzzleVelocityFps': muzzleVelocityFps,
    'bulletWeightGrains': bulletWeightGrains,
    'ballisticCoefficient': ballisticCoefficient,
    'dragModel': dragModel.name,
  };

  factory RifleProfile.fromJson(Map<String, dynamic> json) => RifleProfile(
    name: json['name'] as String,
    caliber: json['caliber'] as String,
    barrelLengthInches: (json['barrelLengthInches'] as num).toDouble(),
    twistRateInches: (json['twistRateInches'] as num).toDouble(),
    sightHeightInches: (json['sightHeightInches'] as num).toDouble(),
    zeroDistanceYards: (json['zeroDistanceYards'] as num).toDouble(),
    clickValueMoa: (json['clickValueMoa'] as num).toDouble(),
    muzzleVelocityFps: (json['muzzleVelocityFps'] as num).toDouble(),
    bulletWeightGrains: (json['bulletWeightGrains'] as num).toDouble(),
    ballisticCoefficient: (json['ballisticCoefficient'] as num).toDouble(),
    dragModel: DragModel.values.byName(json['dragModel'] as String),
  );

  // tells Equatable which fields to compare
  @override
  List<Object?> get props => [
    name,
    caliber,
    barrelLengthInches,
    twistRateInches,
    sightHeightInches,
    zeroDistanceYards,
    clickValueMoa,
    muzzleVelocityFps,
    bulletWeightGrains,
    ballisticCoefficient,
    dragModel,
  ];
}
