import 'dart:math';

import '../models/calibration_record.dart';
import '../models/pattern_result.dart';
import '../models/shotgun_setup.dart';

/// Predicts shotgun pattern spread and pellet density using a Rayleigh
/// distribution model parameterized by choke, wad, ammo class, and optional
/// calibration data.
class PatternEngine {
  // Base spread rate in inches per yard of distance, indexed by choke.
  // Derived from published pattern data for 12 ga with standard loads.
  static const _chokeBaseRate = <ChokeType, double>{
    ChokeType.cylinder: 1.00,
    ChokeType.skeet: 0.90,
    ChokeType.improvedCylinder: 0.80,
    ChokeType.modified: 0.70,
    ChokeType.improvedModified: 0.60,
    ChokeType.full: 0.50,
    ChokeType.extraFull: 0.40,
  };

  /// Predict a pattern at the given distance.
  ///
  /// If [calibration] is provided, its multipliers adjust the base model.
  PatternResult predict({
    required ShotgunSetup setup,
    required double distanceYards,
    CalibrationRecord? calibration,
  }) {
    final baseRate = _chokeBaseRate[setup.chokeType]!;
    final wadMod = setup.wadType.spreadModifier;
    final ammoMod = setup.ammoSpreadClass.sigmaMultiplier;
    final calDiamMod = calibration?.diameterMultiplier ?? 1.0;
    final calSigMod = calibration?.sigmaMultiplier ?? 1.0;

    // Total spread diameter (inches)
    final spreadDiameter =
        baseRate * distanceYards * wadMod * ammoMod * calDiamMod;

    // R50: radius containing 50% of pellets.
    // Heuristic: 50% of pellets land within ~35% of the total spread radius.
    final baseR50 = spreadDiameter * 0.35 / 2.0; // divide diameter by 2
    final r50 = baseR50 * calSigMod;

    // Rayleigh sigma from R50: CDF(R50) = 0.5 → sigma = R50 / sqrt(ln(4))
    final sigma = r50 / sqrt(log(4));

    // R75: CDF(R75) = 0.75 → R75 = sigma * sqrt(2 * ln(4))
    final r75 = sigma * sqrt(2 * log(4));

    final pellets = setup.pelletCount;

    // Pellets in circle of given radius using Rayleigh CDF:
    //   P(r) = 1 - exp(-r^2 / (2 * sigma^2))
    int pelletsInCircle(double radiusInches) {
      final p = 1.0 - exp(-radiusInches * radiusInches / (2 * sigma * sigma));
      return (pellets * p).round();
    }

    final poiX = calibration?.poiOffsetXInches ?? 0.0;
    final poiY = calibration?.poiOffsetYInches ?? 0.0;

    return PatternResult(
      distanceYards: distanceYards,
      spreadDiameterInches: spreadDiameter,
      r50Inches: r50,
      r75Inches: r75,
      pelletsIn10Circle: pelletsInCircle(5.0), // 10" diameter = 5" radius
      pelletsIn20Circle: pelletsInCircle(10.0), // 20" diameter = 10" radius
      poiOffsetXInches: poiX,
      poiOffsetYInches: poiY,
      isCalibrated: calibration != null,
      totalPellets: pellets,
    );
  }
}
