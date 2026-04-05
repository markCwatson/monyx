import 'dart:math';

import '../models/calibration_record.dart';
import '../models/pattern_result.dart';
import '../models/shotgun_setup.dart';

/// Predicts shotgun pattern spread and pellet density using a Rayleigh
/// distribution model anchored to published pattern efficiency (PE) data.
///
/// PE = fraction of pellets in a 30" circle at 40 yards, from Lyman's
/// Shotshell Handbook / NRA Firearms Fact Book.
class PatternEngine {
  /// Pattern efficiency at 40 yards for each choke (12 ga, lead, plastic wad).
  static const _patternEfficiency = <ChokeType, double>{
    ChokeType.cylinder: 0.40,
    ChokeType.skeet: 0.45,
    ChokeType.improvedCylinder: 0.50,
    ChokeType.modified: 0.60,
    ChokeType.improvedModified: 0.65,
    ChokeType.full: 0.70,
    ChokeType.extraFull: 0.73,
  };

  /// Gauge modifier — smaller bores throw slightly wider patterns for the same
  /// named choke constriction.
  static const _gaugeModifier = <Gauge, double>{
    Gauge.g12: 1.00,
    Gauge.g20: 1.05,
    Gauge.g28: 1.08,
    Gauge.g410: 1.12,
  };

  /// Shot material hardness modifier — harder materials deform less and
  /// pattern tighter (lower value = tighter).
  static const _hardnessModifier = <ShotCategory, double>{
    ShotCategory.lead: 1.00,
    ShotCategory.steel: 0.85,
    ShotCategory.bismuth: 0.93,
    ShotCategory.tungsten: 0.87,
    ShotCategory.tss: 0.85,
  };

  /// Derive the Rayleigh σ at 40 yards from a pattern efficiency value.
  ///
  /// PE = CDF(15") = 1 − exp(−15² / (2σ²))
  /// ⇒ σ = 15 / √(−2 ln(1 − PE))
  static double _sigma40FromPE(double pe) {
    return 15.0 / sqrt(-2.0 * log(1.0 - pe));
  }

  /// Predict a pattern at the given distance.
  ///
  /// If [calibration] is provided, its multipliers adjust the base model.
  PatternResult predict({
    required ShotgunSetup setup,
    required double distanceYards,
    CalibrationRecord? calibration,
  }) {
    // 1. Look up PE for choke → derive σ₄₀
    final pe = _patternEfficiency[setup.chokeType]!;
    final sigma40 = _sigma40FromPE(pe);

    // 2. Apply modifiers: gauge, hardness, wad, ammo class
    final gaugeMod = _gaugeModifier[setup.gauge]!;
    final hardnessMod = _hardnessModifier[setup.shotCategory]!;
    final wadMod = setup.wadType.spreadModifier;
    final ammoMod = setup.ammoSpreadClass.sigmaMultiplier;

    final sigma40Adj = sigma40 * gaugeMod * hardnessMod * wadMod * ammoMod;

    // 3. Scale to distance (linear)
    final sigma = sigma40Adj * (distanceYards / 40.0);

    // 4. Apply calibration
    final calDiamMod = calibration?.diameterMultiplier ?? 1.0;
    final calSigMod = calibration?.sigmaMultiplier ?? 1.0;
    final sigmaFinal = sigma * calDiamMod * calSigMod;

    // 5. Derive everything from σ_final
    // R50: CDF(R50) = 0.5 → R50 = σ √(ln 4)
    final r50 = sigmaFinal * sqrt(log(4));

    // R75: CDF(R75) = 0.75 → R75 = σ √(2 ln 4)
    final r75 = sigmaFinal * sqrt(2 * log(4));

    // Spread diameter: 99% containment → CDF(r) = 0.99
    // r = σ √(−2 ln(0.01)) → diameter = 2r
    final spreadDiameter = 2.0 * sigmaFinal * sqrt(-2.0 * log(0.01));

    final pellets = setup.pelletCount;

    // Pellets in circle of given radius using Rayleigh CDF:
    //   P(r) = 1 − exp(−r² / (2σ²))
    int pelletsInCircle(double radiusInches) {
      if (sigmaFinal <= 0) return pellets;
      final p =
          1.0 -
          exp(-radiusInches * radiusInches / (2 * sigmaFinal * sigmaFinal));
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
      patternEfficiency: pe,
    );
  }
}
