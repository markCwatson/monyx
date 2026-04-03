import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:monyx/ballistics/pattern_engine.dart';
import 'package:monyx/models/calibration_record.dart';
import 'package:monyx/models/shotgun_setup.dart';

/// Default 12 ga Modified choke, #6 Lead, plastic wad, standard ammo.
final _default12ga = ShotgunSetup(
  name: 'Test 12ga Mod',
  gauge: Gauge.g12,
  barrelLengthInches: 28,
  chokeType: ChokeType.modified,
  loadName: '#6 Lead',
  shotCategory: ShotCategory.lead,
  shotSize: ShotSize.s6,
  pelletCount: 281,
  muzzleVelocityFps: 1330,
  wadType: WadType.plastic,
  ammoSpreadClass: AmmoSpreadClass.standard,
);

/// Cylinder bore → widest pattern.
final _cylinder = ShotgunSetup(
  name: 'Cylinder',
  gauge: Gauge.g12,
  barrelLengthInches: 26,
  chokeType: ChokeType.cylinder,
  loadName: 'Buck',
  shotCategory: ShotCategory.lead,
  shotSize: ShotSize.s4,
  pelletCount: 135,
  muzzleVelocityFps: 1325,
  wadType: WadType.plastic,
  ammoSpreadClass: AmmoSpreadClass.standard,
);

/// Full choke → tightest common pattern.
final _full = ShotgunSetup(
  name: 'Full',
  gauge: Gauge.g12,
  barrelLengthInches: 30,
  chokeType: ChokeType.full,
  loadName: 'Target',
  shotCategory: ShotCategory.lead,
  shotSize: ShotSize.s8,
  pelletCount: 410,
  muzzleVelocityFps: 1200,
  wadType: WadType.plastic,
  ammoSpreadClass: AmmoSpreadClass.standard,
);

void main() {
  final engine = PatternEngine();

  // ── Spread diameter ──────────────────────────────────────────────

  group('Spread diameter', () {
    test('12ga Modified at 20yds: spread = 0.7 * 20 * 0.9 * 1.0 = 12.6"', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 20);
      // 0.7 (mod) × 20 × 0.90 (plastic) × 1.00 (standard) = 12.6
      expect(r.spreadDiameterInches, closeTo(12.6, 0.01));
    });

    test('Cylinder at 20yds: spread = 1.0 * 20 * 0.9 * 1.0 = 18"', () {
      final r = engine.predict(setup: _cylinder, distanceYards: 20);
      expect(r.spreadDiameterInches, closeTo(18.0, 0.01));
    });

    test('Full at 40yds: spread = 0.5 * 40 * 0.9 * 1.0 = 18"', () {
      final r = engine.predict(setup: _full, distanceYards: 40);
      expect(r.spreadDiameterInches, closeTo(18.0, 0.01));
    });

    test('spread scales linearly with distance', () {
      final r20 = engine.predict(setup: _default12ga, distanceYards: 20);
      final r40 = engine.predict(setup: _default12ga, distanceYards: 40);
      expect(
        r40.spreadDiameterInches,
        closeTo(r20.spreadDiameterInches * 2, 0.01),
      );
    });

    test('tighter choke → smaller spread at same distance', () {
      final rCyl = engine.predict(setup: _cylinder, distanceYards: 30);
      final rMod = engine.predict(setup: _default12ga, distanceYards: 30);
      final rFull = engine.predict(setup: _full, distanceYards: 30);
      expect(rCyl.spreadDiameterInches, greaterThan(rMod.spreadDiameterInches));
      expect(
        rMod.spreadDiameterInches,
        greaterThan(rFull.spreadDiameterInches),
      );
    });
  });

  // ── Wad and ammo modifiers ───────────────────────────────────────

  group('Wad & ammo modifiers', () {
    test('fiber wad increases spread vs plastic', () {
      final plastic = engine.predict(setup: _default12ga, distanceYards: 30);
      final fiber = engine.predict(
        setup: ShotgunSetup(
          name: 'Fiber',
          gauge: Gauge.g12,
          barrelLengthInches: 28,
          chokeType: ChokeType.modified,
          loadName: '#6 Lead',
          shotCategory: ShotCategory.lead,
          shotSize: ShotSize.s6,
          pelletCount: 281,
          muzzleVelocityFps: 1330,
          wadType: WadType.fiber,
          ammoSpreadClass: AmmoSpreadClass.standard,
        ),
        distanceYards: 30,
      );
      // fiber modifier 1.15 > plastic 0.90
      expect(
        fiber.spreadDiameterInches,
        greaterThan(plastic.spreadDiameterInches),
      );
      // Exact ratio: 1.15 / 0.90
      expect(
        fiber.spreadDiameterInches / plastic.spreadDiameterInches,
        closeTo(1.15 / 0.90, 0.001),
      );
    });

    test('wide ammo class increases spread vs standard', () {
      final standard = engine.predict(setup: _default12ga, distanceYards: 30);
      final wide = engine.predict(
        setup: ShotgunSetup(
          name: 'Wide',
          gauge: Gauge.g12,
          barrelLengthInches: 28,
          chokeType: ChokeType.modified,
          loadName: '#6 Lead',
          shotCategory: ShotCategory.lead,
          shotSize: ShotSize.s6,
          pelletCount: 281,
          muzzleVelocityFps: 1330,
          wadType: WadType.plastic,
          ammoSpreadClass: AmmoSpreadClass.wide,
        ),
        distanceYards: 30,
      );
      expect(
        wide.spreadDiameterInches,
        greaterThan(standard.spreadDiameterInches),
      );
      expect(
        wide.spreadDiameterInches / standard.spreadDiameterInches,
        closeTo(1.20 / 1.00, 0.001),
      );
    });
  });

  // ── R50 / R75 / Rayleigh consistency ─────────────────────────────

  group('R50 / R75 Rayleigh distribution', () {
    test('R50 = 35% of spread radius', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 30);
      expect(r.r50Inches, closeTo(r.spreadDiameterInches * 0.35 / 2.0, 0.01));
    });

    test('R75 > R50', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 30);
      expect(r.r75Inches, greaterThan(r.r50Inches));
    });

    test('R75 / R50 matches Rayleigh CDF ratio', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 30);
      // sigma = R50 / sqrt(ln(4))
      // R75 = sigma * sqrt(2 * ln(4))
      // R75 / R50 = sqrt(2 * ln(4)) / sqrt(ln(4)) = sqrt(2)
      expect(r.r75Inches / r.r50Inches, closeTo(sqrt(2), 0.001));
    });
  });

  // ── Pellet counts in circles ─────────────────────────────────────

  group('Pellet counts in circles', () {
    test('20" circle captures more pellets than 10"', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 30);
      expect(r.pelletsIn20Circle, greaterThan(r.pelletsIn10Circle));
    });

    test('both counts ≤ total pellets', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 30);
      expect(r.pelletsIn10Circle, lessThanOrEqualTo(r.totalPellets));
      expect(r.pelletsIn20Circle, lessThanOrEqualTo(r.totalPellets));
    });

    test('very close distance → almost all pellets in 20"', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 5);
      // At 5 yds, spread ≈ 3.15", so a 20" circle should capture nearly all
      expect(r.pelletsIn20Circle, equals(r.totalPellets));
    });

    test('Rayleigh CDF matches pellet count at 10" circle', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 30);
      final sigma = r.r50Inches / sqrt(log(4));
      const radius = 5.0; // 10" diameter
      final p = 1.0 - exp(-radius * radius / (2 * sigma * sigma));
      expect(r.pelletsIn10Circle, equals((281 * p).round()));
    });
  });

  // ── Uncalibrated defaults ────────────────────────────────────────

  group('Uncalibrated defaults', () {
    test('isCalibrated = false when no calibration record', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 20);
      expect(r.isCalibrated, isFalse);
    });

    test('POI offset is zero without calibration', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 20);
      expect(r.poiOffsetXInches, equals(0.0));
      expect(r.poiOffsetYInches, equals(0.0));
    });

    test('distanceYards is echoed in result', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 35);
      expect(r.distanceYards, equals(35));
    });

    test('totalPellets matches setup', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 20);
      expect(r.totalPellets, equals(281));
    });
  });

  // ── Calibration record ───────────────────────────────────────────

  group('Calibration multipliers', () {
    const cal = CalibrationRecord(
      setupId: 'Test 12ga Mod',
      diameterMultiplier: 1.2,
      sigmaMultiplier: 1.1,
      poiOffsetXInches: 0.5,
      poiOffsetYInches: -0.3,
      sampleCount: 3,
      aggregateConfidence: 0.85,
    );

    test('isCalibrated = true with calibration', () {
      final r = engine.predict(
        setup: _default12ga,
        distanceYards: 20,
        calibration: cal,
      );
      expect(r.isCalibrated, isTrue);
    });

    test('diameterMultiplier scales spread', () {
      final uncal = engine.predict(setup: _default12ga, distanceYards: 20);
      final caled = engine.predict(
        setup: _default12ga,
        distanceYards: 20,
        calibration: cal,
      );
      expect(
        caled.spreadDiameterInches,
        closeTo(uncal.spreadDiameterInches * 1.2, 0.01),
      );
    });

    test('sigmaMultiplier scales R50', () {
      final uncal = engine.predict(setup: _default12ga, distanceYards: 20);
      final caled = engine.predict(
        setup: _default12ga,
        distanceYards: 20,
        calibration: cal,
      );
      // R50 is derived from spread * 0.35 / 2 * calSigMod
      // But spread itself is scaled by calDiamMod, so:
      // calR50 = (spread * 1.2) * 0.35 / 2 * 1.1
      expect(caled.r50Inches, closeTo(uncal.r50Inches * 1.2 * 1.1, 0.01));
    });

    test('POI offset is passed through from calibration', () {
      final r = engine.predict(
        setup: _default12ga,
        distanceYards: 20,
        calibration: cal,
      );
      expect(r.poiOffsetXInches, equals(0.5));
      expect(r.poiOffsetYInches, equals(-0.3));
    });

    test('identity calibration (1.0, 1.0) matches uncalibrated', () {
      const identity = CalibrationRecord(
        setupId: 'Test 12ga Mod',
        diameterMultiplier: 1.0,
        sigmaMultiplier: 1.0,
        poiOffsetXInches: 0.0,
        poiOffsetYInches: 0.0,
        sampleCount: 1,
        aggregateConfidence: 0.5,
      );
      final uncal = engine.predict(setup: _default12ga, distanceYards: 25);
      final caled = engine.predict(
        setup: _default12ga,
        distanceYards: 25,
        calibration: identity,
      );
      expect(caled.spreadDiameterInches, equals(uncal.spreadDiameterInches));
      expect(caled.r50Inches, equals(uncal.r50Inches));
      expect(caled.r75Inches, equals(uncal.r75Inches));
      expect(caled.pelletsIn10Circle, equals(uncal.pelletsIn10Circle));
      expect(caled.pelletsIn20Circle, equals(uncal.pelletsIn20Circle));
    });
  });

  // ── All choke types covered ──────────────────────────────────────

  group('All choke types produce valid results', () {
    for (final choke in ChokeType.values) {
      test('${choke.label} at 25yds', () {
        final setup = ShotgunSetup(
          name: choke.label,
          gauge: Gauge.g12,
          barrelLengthInches: 28,
          chokeType: choke,
          loadName: 'Test',
          shotCategory: ShotCategory.lead,
          shotSize: ShotSize.s6,
          pelletCount: 281,
          muzzleVelocityFps: 1330,
          wadType: WadType.plastic,
          ammoSpreadClass: AmmoSpreadClass.standard,
        );
        final r = engine.predict(setup: setup, distanceYards: 25);
        expect(r.spreadDiameterInches, isPositive);
        expect(r.r50Inches, isPositive);
        expect(r.r75Inches, isPositive);
        expect(r.pelletsIn10Circle, greaterThanOrEqualTo(0));
        expect(r.pelletsIn20Circle, greaterThanOrEqualTo(r.pelletsIn10Circle));
        expect(r.totalPellets, equals(281));
      });
    }
  });

  // ── Edge cases ───────────────────────────────────────────────────

  group('Edge cases', () {
    test('zero distance → zero spread', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 0);
      expect(r.spreadDiameterInches, equals(0.0));
    });

    test('very long distance (60yds) still produces valid results', () {
      final r = engine.predict(setup: _default12ga, distanceYards: 60);
      expect(r.spreadDiameterInches, isPositive);
      expect(r.pelletsIn20Circle, lessThanOrEqualTo(r.totalPellets));
    });
  });

  // ── ShotgunSetup serialization ───────────────────────────────────

  group('ShotgunSetup JSON round-trip', () {
    test('fromJson(toJson()) == original', () {
      final json = _default12ga.toJson();
      final restored = ShotgunSetup.fromJson(json);
      expect(restored, equals(_default12ga));
    });

    test('default factory matches expected values', () {
      final d = ShotgunSetup.default12gaMod();
      expect(d.gauge, equals(Gauge.g12));
      expect(d.chokeType, equals(ChokeType.modified));
      expect(d.pelletCount, equals(281));
      expect(d.wadType, equals(WadType.plastic));
      expect(d.ammoSpreadClass, equals(AmmoSpreadClass.standard));
    });
  });

  // ── CalibrationRecord serialization ──────────────────────────────

  group('CalibrationRecord JSON round-trip', () {
    test('round-trip without optional fields', () {
      const rec = CalibrationRecord(
        setupId: 'test',
        diameterMultiplier: 1.1,
        sigmaMultiplier: 0.95,
        poiOffsetXInches: 0.3,
        poiOffsetYInches: -0.2,
        sampleCount: 2,
        aggregateConfidence: 0.7,
      );
      final restored = CalibrationRecord.fromJson(rec.toJson());
      expect(restored, equals(rec));
    });

    test('round-trip with ellipse fields', () {
      const rec = CalibrationRecord(
        setupId: 'test',
        diameterMultiplier: 1.0,
        sigmaMultiplier: 1.0,
        poiOffsetXInches: 0.0,
        poiOffsetYInches: 0.0,
        sampleCount: 1,
        aggregateConfidence: 0.5,
        ellipseRatio: 1.3,
        ellipseAngleDeg: 45.0,
      );
      final restored = CalibrationRecord.fromJson(rec.toJson());
      expect(restored, equals(rec));
      expect(restored.ellipseRatio, equals(1.3));
      expect(restored.ellipseAngleDeg, equals(45.0));
    });
  });
}
