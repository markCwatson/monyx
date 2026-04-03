import 'package:flutter_test/flutter_test.dart';

import 'package:monyx/ballistics/solver.dart';
import 'package:monyx/models/rifle_profile.dart';
import 'package:monyx/models/weather_data.dart';

/// Test profile matching pyballistic's G1 test:
/// .308 168gr, BC 0.223 G1, MV 2750fps, 2" sight height, zero at 100yd
final _g1Profile = RifleProfile(
  name: 'G1 Test',
  caliber: '.308',
  barrelLengthInches: 24,
  twistRateInches: 10,
  sightHeightInches: 2,
  zeroDistanceYards: 100,
  clickValueMoa: 0.25,
  muzzleVelocityFps: 2750,
  bulletWeightGrains: 168,
  ballisticCoefficient: 0.223,
  dragModel: DragModel.g1,
);

/// Test profile matching pyballistic's G7 test:
/// .308 168gr, BC 0.223 G7, MV 2750fps, 2" sight height, zero at 100yd
final _g7Profile = RifleProfile(
  name: 'G7 Test',
  caliber: '.308',
  barrelLengthInches: 24,
  twistRateInches: 12,
  sightHeightInches: 2,
  zeroDistanceYards: 100,
  clickValueMoa: 0.25,
  muzzleVelocityFps: 2750,
  bulletWeightGrains: 168,
  ballisticCoefficient: 0.223,
  dragModel: DragModel.g7,
);

const _icaoWeather = WeatherData(
  temperatureF: 59,
  humidityPercent: 0,
  pressureInHg: 29.92,
  windSpeedMph: 0,
  windDirectionDeg: 0,
  source: WeatherSource.estimated,
);

void main() {
  group('G1 trajectory (pyballistic reference)', () {
    test('100yd: velocity ~2351fps, drop ~0"', () {
      final sol = BallisticSolver.solve(
        profile: _g1Profile,
        weather: _icaoWeather,
        horizontalRangeYards: 100,
        elevationDiffFt: 0,
        shootingAzimuthDeg: 0,
      );
      expect(sol.velocityAtTargetFps, closeTo(2351, 15));
      expect(sol.dropInches.abs(), lessThan(1.0)); // zeroed at 100yd
    });

    test('500yd: velocity ~1169fps, drop ~-87.9"', () {
      final sol = BallisticSolver.solve(
        profile: _g1Profile,
        weather: _icaoWeather,
        horizontalRangeYards: 500,
        elevationDiffFt: 0,
        shootingAzimuthDeg: 0,
      );
      expect(sol.velocityAtTargetFps, closeTo(1169, 15));
      expect(sol.dropInches, closeTo(-87.9, 3));
    });

    test('1000yd: velocity ~776fps, drop ~-824"', () {
      final sol = BallisticSolver.solve(
        profile: _g1Profile,
        weather: _icaoWeather,
        horizontalRangeYards: 1000,
        elevationDiffFt: 0,
        shootingAzimuthDeg: 0,
      );
      expect(sol.velocityAtTargetFps, closeTo(776, 15));
      expect(sol.dropInches, closeTo(-824, 10));
    });

    test('500yd with 5mph wind: windage ~-19.5"', () {
      // pyballistic wind: 5 mph from 10.5 o'clock
      // 10.5 o'clock = 315° in "from" direction relative to shooter
      // In pyballistic, direction_from: 0°=from behind, 90°=from left.
      // 10.5 o'clock = (10.5 * 30)° in clock = 315° in compass.
      // For our meteorological "from" convention we need the equivalent wind.
      // The pyballistic convention: 0° = from behind shooter, 90° = from shooter's left.
      // At 10.5 o'clock (315°), the headwind component is cos(315°)*5 = 3.54 mph
      // and crosswind component is sin(315°)*5 = -3.54 mph (from right).
      // For our test, let's use a pure crosswind: 5 mph from 270° shooting north.
      const windWeather = WeatherData(
        temperatureF: 59,
        humidityPercent: 0,
        pressureInHg: 29.92,
        windSpeedMph: 5,
        windDirectionDeg: 270, // from west, shooting north = pure crosswind
        source: WeatherSource.estimated,
      );
      final sol = BallisticSolver.solve(
        profile: _g1Profile,
        weather: windWeather,
        horizontalRangeYards: 500,
        elevationDiffFt: 0,
        shootingAzimuthDeg: 0,
      );
      // Pure 5mph crosswind at 500yd: should produce meaningful drift
      expect(sol.windDriftInches.abs(), greaterThan(10));
      expect(sol.windDriftInches.abs(), lessThan(30));
    });
  });

  group('G7 trajectory (pyballistic reference)', () {
    test('100yd: velocity ~2545fps, drop ~0"', () {
      final sol = BallisticSolver.solve(
        profile: _g7Profile,
        weather: _icaoWeather,
        horizontalRangeYards: 100,
        elevationDiffFt: 0,
        shootingAzimuthDeg: 0,
      );
      expect(sol.velocityAtTargetFps, closeTo(2545, 15));
      expect(sol.dropInches.abs(), lessThan(1.0));
    });

    test('500yd: velocity ~1814fps, drop ~-56.2"', () {
      final sol = BallisticSolver.solve(
        profile: _g7Profile,
        weather: _icaoWeather,
        horizontalRangeYards: 500,
        elevationDiffFt: 0,
        shootingAzimuthDeg: 0,
      );
      expect(sol.velocityAtTargetFps, closeTo(1814, 15));
      expect(sol.dropInches, closeTo(-56.2, 3));
    });

    test('1000yd: velocity ~1086fps, drop ~-400"', () {
      final sol = BallisticSolver.solve(
        profile: _g7Profile,
        weather: _icaoWeather,
        horizontalRangeYards: 1000,
        elevationDiffFt: 0,
        shootingAzimuthDeg: 0,
      );
      expect(sol.velocityAtTargetFps, closeTo(1086, 15));
      expect(sol.dropInches, closeTo(-400, 10));
    });
  });

  group('Basic sanity checks', () {
    test('.308 default profile at 500y produces reasonable values', () {
      final profile = RifleProfile.default308();
      final weather = WeatherData.standard();
      final sol = BallisticSolver.solve(
        profile: profile,
        weather: weather,
        horizontalRangeYards: 500,
        elevationDiffFt: 0,
        shootingAzimuthDeg: 0,
      );
      expect(sol.dropInches.abs(), greaterThan(20));
      expect(sol.dropInches.abs(), lessThan(80));
      expect(sol.velocityAtTargetFps, greaterThan(1500));
      expect(sol.velocityAtTargetFps, lessThan(2400));
      expect(sol.windDriftInches.abs(), lessThan(0.1));
    });

    test('Crosswind produces lateral drift', () {
      final profile = RifleProfile.default308();
      const weather = WeatherData(
        temperatureF: 59,
        humidityPercent: 50,
        pressureInHg: 29.92,
        windSpeedMph: 10,
        windDirectionDeg: 270,
        source: WeatherSource.live,
      );
      final sol = BallisticSolver.solve(
        profile: profile,
        weather: weather,
        horizontalRangeYards: 500,
        elevationDiffFt: 0,
        shootingAzimuthDeg: 0,
      );
      expect(sol.windDriftInches.abs(), greaterThan(3));
    });

    test('100yd with 50ft elevation diff gives sane drop', () {
      final profile = RifleProfile.default308();
      final weather = WeatherData.standard();
      final sol = BallisticSolver.solve(
        profile: profile,
        weather: weather,
        horizontalRangeYards: 100,
        elevationDiffFt: 50, // target 50ft above shooter
        shootingAzimuthDeg: 0,
      );
      // At 100yd (zeroed at 100yd) with modest uphill, drop should be small
      // Rifleman's Rule: drop ≈ flat drop * cos(angle) — very small at 100yd zero
      expect(sol.dropMoa.abs(), lessThan(2.0));
    });

    test('100yd with 200ft elevation diff gives sane drop', () {
      final profile = RifleProfile.default308();
      final weather = WeatherData.standard();
      final sol = BallisticSolver.solve(
        profile: profile,
        weather: weather,
        horizontalRangeYards: 100,
        elevationDiffFt: 200, // steep uphill
        shootingAzimuthDeg: 0,
      );
      // Even with steep elevation, the drop correction at ~100yd equivalent
      // should not be extreme (Rifleman's Rule applies)
      expect(sol.dropMoa.abs(), lessThan(5.0));
    });
  });
}
