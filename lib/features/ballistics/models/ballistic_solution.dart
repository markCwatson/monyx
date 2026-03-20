/// Complete ballistic solution at a given range.
class BallisticSolution {
  const BallisticSolution({
    required this.rangeYards,
    required this.dropInches,
    required this.elevationCorrectionMoa,
    required this.elevationCorrectionMil,
    required this.elevationClicksUp,
    required this.windDriftInches,
    required this.windCorrectionMoa,
    required this.windCorrectionMil,
    required this.windClicksLeft,
    required this.timeOfFlightSeconds,
    required this.remainingVelocityFps,
    required this.remainingEnergyFtLbs,
    this.spinDriftInches = 0.0,
    this.assumptions = '',
  });

  /// Slant range (yards).
  final double rangeYards;

  /// Bullet drop below line-of-sight (inches).  Negative = below LOS.
  final double dropInches;

  // ── Elevation ──────────────────────────────────────────────────────────────

  /// MOA of elevation dialled UP to hit target.  Positive = dial up.
  final double elevationCorrectionMoa;

  /// Same correction in mils.
  final double elevationCorrectionMil;

  /// Clicks to dial up (positive).
  final int elevationClicksUp;

  // ── Wind ───────────────────────────────────────────────────────────────────

  /// Wind drift in inches.  Positive = pushed right (with right-to-left wind).
  final double windDriftInches;

  /// MOA to correct wind.  Positive = hold/dial left.
  final double windCorrectionMoa;

  /// Mils to correct wind.
  final double windCorrectionMil;

  /// Clicks left (positive = click left).
  final int windClicksLeft;

  // ── Terminal ballistics ────────────────────────────────────────────────────

  final double timeOfFlightSeconds;
  final double remainingVelocityFps;
  final double remainingEnergyFtLbs;

  /// Gyroscopic spin drift (inches, positive = right for right-hand twist).
  final double spinDriftInches;

  /// Human-readable summary of atmospheric assumptions used.
  final String assumptions;

  @override
  String toString() =>
      'BallisticSolution('
      '${rangeYards.toStringAsFixed(0)} yds, '
      'drop: ${dropInches.toStringAsFixed(1)}", '
      'elev: ${elevationCorrectionMoa.toStringAsFixed(2)} MOA, '
      'wind: ${windCorrectionMoa.toStringAsFixed(2)} MOA)';
}
