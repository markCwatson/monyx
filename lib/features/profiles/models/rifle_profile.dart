import 'package:flutter/foundation.dart';

/// Optic unit system.
enum OpticUnit {
  moa,
  mil;

  String get displayName => name.toUpperCase();
}

/// Bullet data for ballistic calculations.
@immutable
class BulletProfile {
  const BulletProfile({
    required this.bulletName,
    required this.bulletWeightGrains,
    required this.muzzleVelocityFps,
    required this.ballisticCoefficientG1,
    required this.bulletDiameterInches,
    this.ballisticCoefficientG7,
  });

  final String bulletName;
  final double bulletWeightGrains;
  final double muzzleVelocityFps;

  /// G1 ballistic coefficient.
  final double ballisticCoefficientG1;

  /// G7 ballistic coefficient (optional – preferred for long-range).
  final double? ballisticCoefficientG7;

  final double bulletDiameterInches;

  factory BulletProfile.fromJson(Map<String, dynamic> json) => BulletProfile(
    bulletName: json['bulletName'] as String,
    bulletWeightGrains: (json['bulletWeightGrains'] as num).toDouble(),
    muzzleVelocityFps: (json['muzzleVelocityFps'] as num).toDouble(),
    ballisticCoefficientG1: (json['ballisticCoefficientG1'] as num).toDouble(),
    ballisticCoefficientG7:
        (json['ballisticCoefficientG7'] as num?)?.toDouble(),
    bulletDiameterInches: (json['bulletDiameterInches'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'bulletName': bulletName,
    'bulletWeightGrains': bulletWeightGrains,
    'muzzleVelocityFps': muzzleVelocityFps,
    'ballisticCoefficientG1': ballisticCoefficientG1,
    'ballisticCoefficientG7': ballisticCoefficientG7,
    'bulletDiameterInches': bulletDiameterInches,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BulletProfile &&
          bulletName == other.bulletName &&
          bulletWeightGrains == other.bulletWeightGrains &&
          muzzleVelocityFps == other.muzzleVelocityFps;

  @override
  int get hashCode =>
      Object.hash(bulletName, bulletWeightGrains, muzzleVelocityFps);
}

/// Complete rifle + optic + ammo configuration for ballistic calculations.
@immutable
class RifleProfile {
  const RifleProfile({
    required this.id,
    required this.name,
    required this.caliber,
    required this.barrelLengthInches,
    required this.twistRateInchesPerTwist,
    required this.zeroDistanceYards,
    required this.sightHeightInches,
    required this.opticUnit,
    required this.clickValueMoa,
    required this.bulletProfile,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String caliber;
  final double barrelLengthInches;

  /// Twist rate in inches per one full rotation (e.g. 10.0 = 1:10 twist).
  final double twistRateInchesPerTwist;

  final double zeroDistanceYards;

  /// Distance in inches from bore centre to optic centre-line.
  final double sightHeightInches;

  final OpticUnit opticUnit;

  /// Adjustment value per click in MOA (e.g. 0.25 for ¼-MOA turrets).
  final double clickValueMoa;

  final BulletProfile bulletProfile;
  final DateTime createdAt;

  factory RifleProfile.fromJson(Map<String, dynamic> json) => RifleProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    caliber: json['caliber'] as String,
    barrelLengthInches: (json['barrelLengthInches'] as num).toDouble(),
    twistRateInchesPerTwist:
        (json['twistRateInchesPerTwist'] as num).toDouble(),
    zeroDistanceYards: (json['zeroDistanceYards'] as num).toDouble(),
    sightHeightInches: (json['sightHeightInches'] as num).toDouble(),
    opticUnit: OpticUnit.values.firstWhere(
      (e) => e.name == json['opticUnit'],
      orElse: () => OpticUnit.moa,
    ),
    clickValueMoa: (json['clickValueMoa'] as num).toDouble(),
    bulletProfile: BulletProfile.fromJson(
      json['bulletProfile'] as Map<String, dynamic>,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'caliber': caliber,
    'barrelLengthInches': barrelLengthInches,
    'twistRateInchesPerTwist': twistRateInchesPerTwist,
    'zeroDistanceYards': zeroDistanceYards,
    'sightHeightInches': sightHeightInches,
    'opticUnit': opticUnit.name,
    'clickValueMoa': clickValueMoa,
    'bulletProfile': bulletProfile.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  RifleProfile copyWith({
    String? id,
    String? name,
    String? caliber,
    double? barrelLengthInches,
    double? twistRateInchesPerTwist,
    double? zeroDistanceYards,
    double? sightHeightInches,
    OpticUnit? opticUnit,
    double? clickValueMoa,
    BulletProfile? bulletProfile,
    DateTime? createdAt,
  }) => RifleProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    caliber: caliber ?? this.caliber,
    barrelLengthInches: barrelLengthInches ?? this.barrelLengthInches,
    twistRateInchesPerTwist:
        twistRateInchesPerTwist ?? this.twistRateInchesPerTwist,
    zeroDistanceYards: zeroDistanceYards ?? this.zeroDistanceYards,
    sightHeightInches: sightHeightInches ?? this.sightHeightInches,
    opticUnit: opticUnit ?? this.opticUnit,
    clickValueMoa: clickValueMoa ?? this.clickValueMoa,
    bulletProfile: bulletProfile ?? this.bulletProfile,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RifleProfile && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'RifleProfile($name, $caliber)';
}

// ── Built-in defaults ─────────────────────────────────────────────────────────

/// Default .308 Win / 168 gr Sierra MatchKing profile.
final kDefaultRifleProfile = RifleProfile(
  id: 'default_308_168smk',
  name: '.308 / 168gr SMK',
  caliber: '.308 Winchester',
  barrelLengthInches: 24.0,
  twistRateInchesPerTwist: 10.0,
  zeroDistanceYards: 100.0,
  sightHeightInches: 1.5,
  opticUnit: OpticUnit.moa,
  clickValueMoa: 0.25,
  bulletProfile: const BulletProfile(
    bulletName: 'Sierra MatchKing 168gr HPBT',
    bulletWeightGrains: 168.0,
    muzzleVelocityFps: 2650.0,
    ballisticCoefficientG1: 0.447,
    ballisticCoefficientG7: 0.223,
    bulletDiameterInches: 0.308,
  ),
  createdAt: DateTime(2024),
);
