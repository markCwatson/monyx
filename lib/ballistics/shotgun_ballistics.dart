import 'dart:math';

import '../models/shotgun_setup.dart';

/// Basic shotgun pellet ballistics: per-pellet energy at distance using a
/// simple drag model. Used to compute lethal effective range.
class ShotgunBallistics {
  ShotgunBallistics._();

  // Base spread rate in inches per yard, by choke — mirrors PatternEngine.
  static const _chokeBaseRate = <ChokeType, double>{
    ChokeType.cylinder: 1.00,
    ChokeType.skeet: 0.90,
    ChokeType.improvedCylinder: 0.80,
    ChokeType.modified: 0.70,
    ChokeType.improvedModified: 0.60,
    ChokeType.full: 0.50,
    ChokeType.extraFull: 0.40,
  };

  /// Mass of a single pellet in grains.
  static double pelletMassGrains(ShotgunSetup setup) {
    // Volume of sphere: V = (4/3) π r³ (inches)
    // Mass = V × density(g/cc) × (inches³→cm³) × (g→grains)
    // 1 in³ = 16.387064 cm³ ; 1 g = 15.4324 grains
    final r = setup.shotSize.diameterInches / 2.0;
    final volumeIn3 = (4.0 / 3.0) * pi * r * r * r;
    final volumeCc = volumeIn3 * 16.387064;
    final massGrams = volumeCc * setup.shotCategory.densityGcc;
    return massGrams * 15.4324;
  }

  /// Per-pellet velocity at [distanceYards] using a simple exponential drag
  /// decay model. Uses a drag coefficient scaled by pellet diameter (larger
  /// pellets retain velocity better).
  static double velocityAtDistance(ShotgunSetup setup, double distanceYards) {
    final v0 = setup.muzzleVelocityFps;
    // Ballistic coefficient approximation for round ball:
    //   BC ≈ (mass in lbs) / (diameter² × form factor)
    // Form factor for sphere ≈ 1.5
    final massLbs = pelletMassGrains(setup) / 7000.0;
    final d = setup.shotSize.diameterInches;
    final bc = massLbs / (d * d * 1.5);

    // Exponential velocity decay: v(x) = v0 × exp(-k × x)
    // k ≈ 1 / (bc × 6000)  (empirical scaling for fps / yards, approx matches
    // published pellet deceleration tables for lead shot)
    final k = 1.0 / (bc * 6000.0);
    return v0 * exp(-k * distanceYards);
  }

  /// Per-pellet kinetic energy (ft-lbs) at [distanceYards].
  static double energyAtDistance(ShotgunSetup setup, double distanceYards) {
    final v = velocityAtDistance(setup, distanceYards);
    final massGr = pelletMassGrains(setup);
    // KE = (mass_grains × v²) / 450,437
    return (massGr * v * v) / 450437.0;
  }

  /// P(X ≥ k) where X ~ Binomial(n, p).
  ///
  /// Computes the exact CDF up to k-1 and subtracts from 1.
  static double _binomialSurvival(int n, double p, int k) {
    if (k <= 0) return 1.0;
    if (k > n || p <= 0) return 0.0;
    if (p >= 1.0) return 1.0;

    final q = 1.0 - p;
    double term = pow(q, n).toDouble();
    double cdf = term;
    for (int i = 1; i < k; i++) {
      term *= (n - i + 1) / i * p / q;
      cdf += term;
    }
    return (1.0 - cdf).clamp(0.0, 1.0);
  }

  /// Probability that a single pellet lands inside a circle of
  /// [diameterInches] at [distanceYards] (Rayleigh CDF).
  static double _pInVital(
    ShotgunSetup setup,
    double distanceYards,
    double diameterInches,
  ) {
    final baseRate = _chokeBaseRate[setup.chokeType]!;
    final wadMod = setup.wadType.spreadModifier;
    final ammoMod = setup.ammoSpreadClass.sigmaMultiplier;

    final spreadDiameter = baseRate * distanceYards * wadMod * ammoMod;
    if (spreadDiameter <= 0) return 1.0;

    final r50 = spreadDiameter * 0.35 / 2.0;
    final sigma = r50 / sqrt(log(4));
    final r = diameterInches / 2.0;
    return 1.0 - exp(-r * r / (2 * sigma * sigma));
  }

  /// Compute the effective hunting range in yards for the setup's [GameTarget].
  ///
  /// The range is the **minimum** of two constraints:
  ///  1. Per-pellet energy must exceed the target's penetration threshold.
  ///  2. With ≥ 80 % confidence (binomial distribution), enough pellets hit
  ///     the vital zone to deliver the required total energy.
  ///
  /// Uses binary search for accuracy (within 0.5 yards).
  static double effectiveRangeYards(ShotgunSetup setup) {
    final target = setup.gameTarget;
    final energyThreshold = target.minPelletEnergyFtLbs;
    final vitalDiameter = target.vitalDiameterInches;
    final vitalEnergy = target.minVitalEnergyFtLbs;
    const confidence = 0.80;

    // ── 1. Energy-limited range ──
    double energyRange = 0;
    final muzzleEnergy = energyAtDistance(setup, 0);
    if (muzzleEnergy >= energyThreshold) {
      double lo = 0, hi = 300;
      while (hi - lo > 0.5) {
        final mid = (lo + hi) / 2;
        if (energyAtDistance(setup, mid) > energyThreshold) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      energyRange = (lo + hi) / 2;
    }

    // ── 2. Confidence-limited range ──
    // Find the farthest distance where the probability of delivering
    // ≥ vitalEnergy ft-lbs to the vital zone is at least `confidence`.
    double confRange = 0;
    final n = setup.pelletCount;
    if (n >= 1) {
      double lo = 0, hi = 300;
      while (hi - lo > 0.5) {
        final mid = (lo + hi) / 2;
        final ePellet = energyAtDistance(setup, mid);
        final kMin = (ePellet > 0) ? (vitalEnergy / ePellet).ceil() : n + 1;
        final p = _pInVital(setup, mid, vitalDiameter);
        final prob = _binomialSurvival(n, p, kMin);
        if (prob >= confidence) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      confRange = (lo + hi) / 2;
    }

    return min(energyRange, confRange);
  }
}
