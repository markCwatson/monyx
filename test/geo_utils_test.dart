import 'package:flutter_test/flutter_test.dart';

import 'package:monyx/core/utils/geo_utils.dart';

void main() {
  // ── Haversine distance ────────────────────────────────────────────────────────

  group('haversineDistance', () {
    test('distance between same point is zero', () {
      expect(GeoUtils.haversineDistance(40.0, -105.0, 40.0, -105.0), 0.0);
    });

    test('known distance: Denver to Colorado Springs (~113 km)', () {
      // Denver, CO: 39.7392° N, 104.9903° W
      // Colorado Springs, CO: 38.8339° N, 104.8214° W
      final dist = GeoUtils.haversineDistance(
        39.7392, -104.9903,
        38.8339, -104.8214,
      );
      // Accept ±2 km tolerance
      expect(dist, greaterThan(111000));
      expect(dist, lessThan(115000));
    });

    test('known distance: equatorial degree ≈ 111.32 km', () {
      final dist = GeoUtils.haversineDistance(0.0, 0.0, 0.0, 1.0);
      expect(dist, closeTo(111320, 500));
    });

    test('distance is symmetric', () {
      final d1 = GeoUtils.haversineDistance(44.5, -110.5, 45.0, -111.0);
      final d2 = GeoUtils.haversineDistance(45.0, -111.0, 44.5, -110.5);
      expect(d1, closeTo(d2, 1.0));
    });
  });

  // ── Bearing ───────────────────────────────────────────────────────────────────

  group('calculateBearing', () {
    test('due north is 0°', () {
      final bearing = GeoUtils.calculateBearing(0.0, 0.0, 1.0, 0.0);
      expect(bearing, closeTo(0.0, 0.01));
    });

    test('due east is 90°', () {
      final bearing = GeoUtils.calculateBearing(0.0, 0.0, 0.0, 1.0);
      expect(bearing, closeTo(90.0, 0.1));
    });

    test('due south is 180°', () {
      final bearing = GeoUtils.calculateBearing(1.0, 0.0, 0.0, 0.0);
      expect(bearing, closeTo(180.0, 0.1));
    });

    test('due west is 270°', () {
      final bearing = GeoUtils.calculateBearing(0.0, 1.0, 0.0, 0.0);
      expect(bearing, closeTo(270.0, 0.1));
    });

    test('bearing is within [0, 360)', () {
      for (final pts in [
        [40.0, -105.0, 38.0, -106.0],
        [10.0, 20.0, -10.0, 200.0],
      ]) {
        final b = GeoUtils.calculateBearing(pts[0], pts[1], pts[2], pts[3]);
        expect(b, greaterThanOrEqualTo(0.0));
        expect(b, lessThan(360.0));
      }
    });
  });

  // ── Shooting angle ────────────────────────────────────────────────────────────

  group('shootingAngleDeg', () {
    test('flat shot is 0°', () {
      expect(GeoUtils.shootingAngleDeg(500, 0), closeTo(0.0, 0.001));
    });

    test('45° uphill when elevation equals distance', () {
      expect(GeoUtils.shootingAngleDeg(100, 100), closeTo(45.0, 0.01));
    });

    test('negative angle for downhill shot', () {
      expect(GeoUtils.shootingAngleDeg(100, -50), lessThan(0));
    });

    test('zero distance returns 0', () {
      expect(GeoUtils.shootingAngleDeg(0, 100), closeTo(0.0, 0.001));
    });
  });

  // ── Unit conversions ──────────────────────────────────────────────────────────

  group('unit conversions', () {
    test('meters to yards: 1 m ≈ 1.0936 yds', () {
      expect(GeoUtils.metersToYards(1.0), closeTo(1.09361, 0.00001));
    });

    test('yards to meters: 1 yd = 0.9144 m', () {
      expect(GeoUtils.yardsToMeters(1.0), closeTo(0.9144, 0.0001));
    });

    test('metersToYards and yardsToMeters are inverses', () {
      const v = 914.4;
      expect(GeoUtils.yardsToMeters(GeoUtils.metersToYards(v)), closeTo(v, 0.001));
    });

    test('feet to meters: 1 ft = 0.3048 m', () {
      expect(GeoUtils.feetToMeters(1.0), closeTo(0.3048, 0.00001));
    });

    test('meters to feet: 1 m ≈ 3.2808 ft', () {
      expect(GeoUtils.metersToFeet(1.0), closeTo(3.28084, 0.00001));
    });

    test('feetToMeters and metersToFeet are inverses', () {
      const v = 500.0;
      expect(GeoUtils.metersToFeet(GeoUtils.feetToMeters(v)), closeTo(v, 0.001));
    });

    test('mph to m/s: 1 mph = 0.44704 m/s', () {
      expect(GeoUtils.mphToMs(1.0), closeTo(0.44704, 0.00001));
    });

    test('m/s to mph round-trip', () {
      const v = 10.0;
      expect(GeoUtils.msToMph(GeoUtils.mphToMs(v)), closeTo(v, 0.001));
    });

    test('fps to m/s: 1 fps = 0.3048 m/s', () {
      expect(GeoUtils.fpsToMs(1.0), closeTo(0.3048, 0.00001));
    });

    test('Celsius to Fahrenheit: 0°C = 32°F', () {
      expect(GeoUtils.celsiusToFahrenheit(0.0), closeTo(32.0, 0.001));
    });

    test('Celsius to Fahrenheit: 100°C = 212°F', () {
      expect(GeoUtils.celsiusToFahrenheit(100.0), closeTo(212.0, 0.001));
    });

    test('fahrenheitToCelsius and celsiusToFahrenheit are inverses', () {
      const v = 59.0;
      expect(
        GeoUtils.fahrenheitToCelsius(GeoUtils.celsiusToFahrenheit(v)),
        closeTo(v, 0.001),
      );
    });

    test('hPa to inHg: 1013.25 hPa ≈ 29.92 inHg', () {
      expect(GeoUtils.hPaToInHg(1013.25), closeTo(29.92, 0.01));
    });

    test('inHg to Pascals: 29.92 inHg ≈ 101325 Pa', () {
      expect(GeoUtils.inHgToPascals(29.92), closeTo(101325, 100));
    });
  });
}
