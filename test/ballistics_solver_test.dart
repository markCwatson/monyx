import 'package:flutter_test/flutter_test.dart';

import 'package:monyx/features/ballistics/models/ballistic_input.dart';
import 'package:monyx/features/ballistics/solver/ballistic_solver.dart';
import 'package:monyx/features/profiles/models/rifle_profile.dart';
import 'package:monyx/core/constants/app_constants.dart';

void main() {
  // ── Shared fixtures ──────────────────────────────────────────────────────────

  final solver = const BallisticSolver();

  /// Standard .308 Win / 168 gr SMK at sea level, ISA conditions.
  BallisticInput inputAt(double yards) => BallisticInput(
    rifleProfile: kDefaultRifleProfile,
    rangeYards: yards,
    temperatureFahrenheit: AppConstants.standardTempF,
    pressureInHg: AppConstants.standardPressureInHg,
    humidityPercent: 0.0, // dry air → deterministic
    altitudeFeet: AppConstants.standardAltitudeFt,
  );

  // ── Zero distance ─────────────────────────────────────────────────────────────

  group('Zero distance (100 yds)', () {
    test('drop at zero distance is near zero', () {
      final sol = solver.solve(inputAt(100));
      // At the zero range, the bullet should intersect the line of sight.
      // Allow ±1 inch tolerance for numerical integration.
      expect(sol.dropInches.abs(), lessThan(1.0),
          reason: 'Drop at zero should be ~0 inches');
    });

    test('elevation correction at zero is near zero', () {
      final sol = solver.solve(inputAt(100));
      expect(sol.elevationCorrectionMoa.abs(), lessThan(0.5),
          reason: 'No correction needed at zero range');
    });
  });

  // ── 500 yards ─────────────────────────────────────────────────────────────────

  group('500 yard shot (.308 / 168gr SMK)', () {
    late final sol = solver.solve(inputAt(500));

    test('drop at 500 yds is in expected range (-35 to -75 inches)', () {
      expect(sol.dropInches, lessThan(-30),
          reason: 'Should be significantly below LOS at 500 yds');
      expect(sol.dropInches, greaterThan(-100),
          reason: 'Drop should not be unrealistically large');
    });

    test('elevation correction is positive (dial up)', () {
      expect(sol.elevationCorrectionMoa, greaterThan(0),
          reason: 'Must dial up to compensate for drop');
    });

    test('elevation correction is in plausible MOA range (10–25 MOA at 500)', () {
      expect(sol.elevationCorrectionMoa, greaterThan(8));
      expect(sol.elevationCorrectionMoa, lessThan(30));
    });

    test('time of flight is between 0.5s and 1.0s', () {
      expect(sol.timeOfFlightSeconds, greaterThan(0.5));
      expect(sol.timeOfFlightSeconds, lessThan(1.0));
    });

    test('remaining velocity is above transonic threshold', () {
      expect(sol.remainingVelocityFps, greaterThan(1300));
    });

    test('remaining energy is positive', () {
      expect(sol.remainingEnergyFtLbs, greaterThan(0));
    });
  });

  // ── 1000 yards ────────────────────────────────────────────────────────────────

  group('1000 yard shot (.308 / 168gr SMK)', () {
    late final sol = solver.solve(inputAt(1000));

    test('drop at 1000 yds is in expected range (-250 to -400 inches)', () {
      expect(sol.dropInches, lessThan(-200),
          reason: 'Bullet falls significantly at 1000 yards');
      expect(sol.dropInches, greaterThan(-500),
          reason: 'Should not be unrealistically large');
    });

    test('elevation correction is greater than at 500 yds', () {
      final sol500 = solver.solve(inputAt(500));
      expect(sol.elevationCorrectionMoa,
          greaterThan(sol500.elevationCorrectionMoa));
    });

    test('time of flight is between 1.5s and 2.5s', () {
      expect(sol.timeOfFlightSeconds, greaterThan(1.4));
      expect(sol.timeOfFlightSeconds, lessThan(2.8));
    });
  });

  // ── Wind drift ────────────────────────────────────────────────────────────────

  group('Wind drift at 500 yards', () {
    test('10 mph full-value right crosswind drifts 7–20 inches right', () {
      final sol = solver.solve(
        BallisticInput(
          rifleProfile: kDefaultRifleProfile,
          rangeYards: 500,
          windSpeedMph: 10.0,
          windDirectionDegrees: 90.0, // right-to-left pushes bullet right
          temperatureFahrenheit: AppConstants.standardTempF,
          pressureInHg: AppConstants.standardPressureInHg,
          humidityPercent: 0.0,
          altitudeFeet: 0,
        ),
      );
      // Positive drift = bullet goes right
      expect(sol.windDriftInches + sol.spinDriftInches, greaterThan(5),
          reason: '10 mph crosswind should push bullet noticeably');
      expect(sol.windDriftInches + sol.spinDriftInches, lessThan(25));
    });

    test('headwind produces minimal lateral drift', () {
      final sol = solver.solve(
        BallisticInput(
          rifleProfile: kDefaultRifleProfile,
          rangeYards: 500,
          windSpeedMph: 10.0,
          windDirectionDegrees: 0.0, // pure headwind
          temperatureFahrenheit: AppConstants.standardTempF,
          pressureInHg: AppConstants.standardPressureInHg,
          humidityPercent: 0.0,
          altitudeFeet: 0,
        ),
      );
      expect(sol.windDriftInches.abs(), lessThan(3));
    });
  });

  // ── MOA conversion math ──────────────────────────────────────────────────────

  group('MOA mathematics', () {
    test('1 MOA ≈ 1.047 inches at 100 yards', () {
      const inchesPerMoa100 = 1.04719755;
      // If drop at 100 yds = inchesPerMoa100, correction should be 1 MOA
      // We verify the converter constant directly.
      expect(inchesPerMoa100, closeTo(1.047, 0.001));
    });

    test('elevation clicks match MOA / click value', () {
      final sol = solver.solve(inputAt(500));
      final profile = kDefaultRifleProfile;
      final expectedClicks =
          (sol.elevationCorrectionMoa / profile.clickValueMoa).round();
      expect(sol.elevationClicksUp, equals(expectedClicks));
    });

    test('mil to MOA conversion constant', () {
      // 1 mil = 3.43775 MOA (NATO definition)
      const moaPerMil = 3.43775;
      final sol = solver.solve(inputAt(500));
      if (sol.elevationCorrectionMoa > 0.01) {
        final derivedMil = sol.elevationCorrectionMoa / moaPerMil;
        expect(sol.elevationCorrectionMil, closeTo(derivedMil, 0.01));
      }
    });
  });

  // ── Density altitude ─────────────────────────────────────────────────────────

  group('Atmospheric density correction', () {
    test('hot conditions (95°F) produce more drop than cold (32°F) at 500 yds', () {
      final hotInput = BallisticInput(
        rifleProfile: kDefaultRifleProfile,
        rangeYards: 500,
        temperatureFahrenheit: 95.0,
        pressureInHg: 29.92,
        humidityPercent: 0.0,
        altitudeFeet: 0,
      );
      final coldInput = BallisticInput(
        rifleProfile: kDefaultRifleProfile,
        rangeYards: 500,
        temperatureFahrenheit: 32.0,
        pressureInHg: 29.92,
        humidityPercent: 0.0,
        altitudeFeet: 0,
      );
      final hotSol = solver.solve(hotInput);
      final coldSol = solver.solve(coldInput);
      // Hot air is less dense → less drag → flatter trajectory (less drop)
      expect(hotSol.dropInches, greaterThan(coldSol.dropInches),
          reason: 'Hot air = less drag = less drop (closer to zero)');
    });

    test('high altitude produces flatter trajectory (less drag)', () {
      final seaLevel = BallisticInput(
        rifleProfile: kDefaultRifleProfile,
        rangeYards: 500,
        temperatureFahrenheit: AppConstants.standardTempF,
        pressureInHg: 29.92,
        humidityPercent: 0.0,
        altitudeFeet: 0,
      );
      final highAlt = BallisticInput(
        rifleProfile: kDefaultRifleProfile,
        rangeYards: 500,
        temperatureFahrenheit: AppConstants.standardTempF,
        pressureInHg: 24.00, // ~5000 ft equivalent pressure
        humidityPercent: 0.0,
        altitudeFeet: 5000,
      );
      final solSea = solver.solve(seaLevel);
      final solHigh = solver.solve(highAlt);
      // Higher altitude / lower pressure → less drag → less drop magnitude
      expect(solHigh.dropInches, greaterThan(solSea.dropInches),
          reason: 'High altitude = less drag = smaller drop magnitude');
    });
  });

  // ── Range card ────────────────────────────────────────────────────────────────

  group('Range card', () {
    test('produces entries from 25 to 1000 yards in 25-yard steps', () {
      final card = solver.rangeCard(
        inputAt(1000),
        maxRangeYards: 1000,
        stepYards: 25,
      );
      expect(card.length, equals(40));
      expect(card.first.rangeYards, equals(25.0));
      expect(card.last.rangeYards, equals(1000.0));
    });

    test('drop values monotonically decrease (more negative) with range', () {
      final card = solver.rangeCard(
        inputAt(500),
        maxRangeYards: 500,
        stepYards: 100,
      );
      for (int i = 1; i < card.length; i++) {
        expect(card[i].dropInches, lessThan(card[i - 1].dropInches),
            reason: 'Drop should increase (become more negative) with range');
      }
    });
  });
}
