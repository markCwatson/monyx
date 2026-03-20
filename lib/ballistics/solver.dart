import 'dart:math';

import '../models/rifle_profile.dart';
import '../models/shot_solution.dart';
import '../models/weather_data.dart';
import 'atmosphere.dart';
import 'conversions.dart';
import 'drag_tables.dart';

/// Point-mass 3-DoF ballistic solver using RK4 integration.
/// Ported from pyballistic (py-ballisticcalc) RK4 engine.
class BallisticSolver {
  /// Standard Drag Factor constant = std_density * π / (4 * 2 * 144)
  /// where std_density = 0.076474 lb/ft³
  static const double _kSdf = 2.08551e-04;

  /// Gravity in ft/s²
  static const double _g = 32.17405;

  /// Time step for RK4 integration (matches pyballistic DEFAULT_TIME_STEP)
  static const double _dt = 0.0025;

  /// Pre-built PCHIP splines (lazily initialised once).
  static PchipSpline? _g1Spline;
  static PchipSpline? _g7Spline;

  static PchipSpline _splineFor(DragModel model) {
    if (model == DragModel.g1) {
      return _g1Spline ??= PchipSpline.fromTable(g1DragTable);
    }
    return _g7Spline ??= PchipSpline.fromTable(g7DragTable);
  }

  /// drag_by_mach(mach) = cd(mach) * _kSdf / bc
  static double _dragByMach(double mach, PchipSpline spline, double bc) {
    return spline.eval(mach) * _kSdf / bc;
  }

  /// Compute a full shot solution.
  static ShotSolution solve({
    required RifleProfile profile,
    required WeatherData weather,
    required double horizontalRangeYards,
    required double elevationDiffFt,
    required double shootingAzimuthDeg,
  }) {
    final spline = _splineFor(profile.dragModel);

    // Atmosphere at station
    final atmo = AtmoState.fromWeather(
      tempF: weather.temperatureF,
      pressureInHg: weather.pressureInHg,
      humidityPercent: weather.humidityPercent,
      altitudeFt: weather.altitudeFt,
    );
    final da = densityAltitude(
      tempF: weather.temperatureF,
      pressureInHg: weather.pressureInHg,
      humidityPercent: weather.humidityPercent,
    );

    // Wind decomposition → ft/s
    final (headwind, crosswind) = decomposeWind(
      windSpeedMph: weather.windSpeedMph,
      windFromDeg: weather.windDirectionDeg,
      shootingAzimuthDeg: shootingAzimuthDeg,
    );
    final wxFps = -headwind * 5280.0 / 3600.0; // tailwind positive
    final wzFps = crosswind * 5280.0 / 3600.0;

    // Shot geometry
    final slantRangeYds = slantRange(horizontalRangeYards, elevationDiffFt);
    final angleDeg = shotAngleDeg(horizontalRangeYards, elevationDiffFt);
    final angleRad = angleDeg * pi / 180.0;

    // Zero under ICAO standard conditions
    final icao = AtmoState.icao();
    final zeroAngle = _findZeroAngle(
      mv: profile.muzzleVelocityFps,
      bc: profile.ballisticCoefficient,
      spline: spline,
      sightHeightIn: profile.sightHeightInches,
      zeroRangeYd: profile.zeroDistanceYards,
      atmo: icao,
    );

    // Trajectory to target under actual conditions.
    // The RK4 loop tracks x = horizontal distance, so we run to the
    // HORIZONTAL range (not slant range). The slant range is only used
    // for angular (MOA) conversion at the end.
    final launchAngle = zeroAngle + angleRad;
    final horizDistFt = horizontalRangeYards * 3.0;

    final result = _runTrajectory(
      mv: profile.muzzleVelocityFps,
      bc: profile.ballisticCoefficient,
      spline: spline,
      launchAngle: launchAngle,
      targetDistFt: horizDistFt,
      atmo: atmo,
      wxFps: wxFps,
      wzFps: wzFps,
    );

    // Line-of-sight from scope (0, sightHeight) to target (horizDist, elevDiff).
    final sightHeightFt = profile.sightHeightInches / 12.0;
    final zeroRangeFt = profile.zeroDistanceYards * 3.0;
    // At the target x, the LOS y accounts for both sight height and target
    // elevation. We interpolate LOS from (0, sightHeight) → (targetX, targetY)
    // where targetY = elevDiffFt, but the zero was found so the bullet
    // returns to y=0 at zeroRange under ICAO. So the LOS at any x is:
    //   losY = sightHeight * (1 - x / zeroRange) + elevDiff * (x / horizDist)
    // The first term is the zero-range sight-height contribution.
    // The second term is the elevation of the target at that x.
    final xRatio = result.distanceFt / horizDistFt;
    final losY =
        sightHeightFt * (1.0 - result.distanceFt / zeroRangeFt) +
        elevationDiffFt * xRatio;

    final dropFt = result.yFt - losY;
    final dropIn = dropFt * 12.0;
    final driftIn = result.zFt * 12.0;
    final dropMoa = inchesToMoa(dropIn, slantRangeYds);
    final driftMoa = inchesToMoa(driftIn, slantRangeYds);
    final dropClk = moaToClicks(dropMoa, profile.clickValueMoa);
    final driftClk = moaToClicks(driftMoa, profile.clickValueMoa);

    final massSlug = profile.bulletWeightGrains / (7000.0 * _g);
    final ke = 0.5 * massSlug * result.velocityFps * result.velocityFps;

    return ShotSolution(
      rangeYards: slantRangeYds,
      shotAngleDeg: angleDeg,
      dropInches: dropIn,
      dropMoa: dropMoa,
      dropClicks: dropClk,
      windDriftInches: driftIn,
      windDriftMoa: driftMoa,
      windDriftClicks: driftClk,
      velocityAtTargetFps: result.velocityFps,
      energyAtTargetFtLbs: ke,
      timeOfFlightSec: result.tof,
      densityAltitudeFt: da,
      weatherSource: weather.source,
      headwindMph: headwind,
      crosswindMph: crosswind,
    );
  }

  /// Find bore elevation angle (rad) so drop = 0 at zero range.
  /// Uses Ridder's method matching pyballistic.
  static double _findZeroAngle({
    required double mv,
    required double bc,
    required PchipSpline spline,
    required double sightHeightIn,
    required double zeroRangeYd,
    required AtmoState atmo,
  }) {
    final zeroRangeFt = zeroRangeYd * 3.0;

    double errorAt(double angle) {
      final r = _runTrajectory(
        mv: mv,
        bc: bc,
        spline: spline,
        launchAngle: angle,
        targetDistFt: zeroRangeFt,
        atmo: atmo,
        wxFps: 0,
        wzFps: 0,
      );
      return r.yFt;
    }

    double low = 0.0;
    double high = 0.05;
    double fLow = errorAt(low);
    double fHigh = errorAt(high);

    // Ridder's method
    for (int i = 0; i < 60; i++) {
      final mid = (low + high) / 2.0;
      final fMid = errorAt(mid);

      final s = sqrt(fMid * fMid - fLow * fHigh);
      if (s == 0) break;

      final next = mid + (mid - low) * (fLow > fHigh ? 1 : -1) * fMid / s;

      if ((next - mid).abs() < 1e-12) break;

      final fNext = errorAt(next);

      if (fMid * fNext < 0) {
        low = mid;
        fLow = fMid;
        high = next;
        fHigh = fNext;
      } else if (fLow * fNext < 0) {
        high = next;
        fHigh = fNext;
      } else {
        low = next;
        fLow = fNext;
      }

      if ((high - low).abs() < 1e-12) break;
    }
    return (low + high) / 2.0;
  }

  /// Run trajectory, return state at target distance.
  /// Matches pyballistic RK4 integration loop.
  static _TrajectoryResult _runTrajectory({
    required double mv,
    required double bc,
    required PchipSpline spline,
    required double launchAngle,
    required double targetDistFt,
    required AtmoState atmo,
    required double wxFps,
    required double wzFps,
  }) {
    // Position
    double x = 0, y = 0, z = 0;
    // Ground velocity
    double vx = mv * cos(launchAngle);
    double vy = mv * sin(launchAngle);
    double vz = 0;
    double t = 0;
    const dt = _dt;

    while (x < targetDistFt && t < 10.0) {
      // Altitude-dependent density & Mach
      final (densityRatio, machFps) = atmo.densityAndMachAt(
        atmo.baseAltitudeFt + y,
      );

      // Relative velocity (air-relative)
      final rvx = vx - wxFps;
      final rvy = vy;
      final rvz = vz - wzFps;
      final relSpeed = sqrt(rvx * rvx + rvy * rvy + rvz * rvz);

      // Pre-compute drag coefficient for this step (pyballistic computes k_m once per step)
      final km = densityRatio * _dragByMach(relSpeed / machFps, spline, bc);

      // Acceleration helper — gravity + drag (opposing air-relative vel)
      (double ax, double ay, double az) accel(
        double rvx,
        double rvy,
        double rvz,
      ) {
        final mag = sqrt(rvx * rvx + rvy * rvy + rvz * rvz);
        return (-km * rvx * mag, -km * rvy * mag - _g, -km * rvz * mag);
      }

      // RK4 integration
      // k1
      final (a1x, a1y, a1z) = accel(rvx, rvy, rvz);

      // k2
      final v2x = vx + 0.5 * dt * a1x;
      final v2y = vy + 0.5 * dt * a1y;
      final v2z = vz + 0.5 * dt * a1z;
      final (a2x, a2y, a2z) = accel(v2x - wxFps, v2y, v2z - wzFps);

      // k3
      final v3x = vx + 0.5 * dt * a2x;
      final v3y = vy + 0.5 * dt * a2y;
      final v3z = vz + 0.5 * dt * a2z;
      final (a3x, a3y, a3z) = accel(v3x - wxFps, v3y, v3z - wzFps);

      // k4
      final v4x = vx + dt * a3x;
      final v4y = vy + dt * a3y;
      final v4z = vz + dt * a3z;
      final (a4x, a4y, a4z) = accel(v4x - wxFps, v4y, v4z - wzFps);

      // Update velocity (save original for position update)
      final v1x = vx, v1y = vy, v1z = vz;
      vx += dt / 6.0 * (a1x + 2 * a2x + 2 * a3x + a4x);
      vy += dt / 6.0 * (a1y + 2 * a2y + 2 * a3y + a4y);
      vz += dt / 6.0 * (a1z + 2 * a2z + 2 * a3z + a4z);

      // Update position: (v1 + 2*v2 + 2*v3 + v4) / 6 * dt
      x += dt / 6.0 * (v1x + 2 * v2x + 2 * v3x + v4x);
      y += dt / 6.0 * (v1y + 2 * v2y + 2 * v3y + v4y);
      z += dt / 6.0 * (v1z + 2 * v2z + 2 * v3z + v4z);

      t += dt;
    }

    final velocity = sqrt(vx * vx + vy * vy + vz * vz);
    return _TrajectoryResult(
      distanceFt: x,
      yFt: y,
      zFt: z,
      velocityFps: velocity,
      tof: t,
    );
  }
}

class _TrajectoryResult {
  final double distanceFt;
  final double yFt;
  final double zFt;
  final double velocityFps;
  final double tof;
  const _TrajectoryResult({
    required this.distanceFt,
    required this.yFt,
    required this.zFt,
    required this.velocityFps,
    required this.tof,
  });
}
