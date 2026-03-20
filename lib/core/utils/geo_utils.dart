import 'dart:math' as math;

/// Geodetic and unit-conversion utilities.
class GeoUtils {
  GeoUtils._();

  // ── Distance ─────────────────────────────────────────────────────────────────

  /// Haversine great-circle distance between two WGS-84 coordinates.
  /// Returns distance in **metres**.
  static double haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double r = 6371000.0; // Earth radius in metres
    final double dLat = _toRad(lat2 - lat1);
    final double dLon = _toRad(lon2 - lon1);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  // ── Bearing ──────────────────────────────────────────────────────────────────

  /// Initial bearing from point 1 → point 2, in degrees (0–360, clockwise from N).
  static double calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final double lat1R = _toRad(lat1);
    final double lat2R = _toRad(lat2);
    final double dLonR = _toRad(lon2 - lon1);
    final double y = math.sin(dLonR) * math.cos(lat2R);
    final double x =
        math.cos(lat1R) * math.sin(lat2R) -
        math.sin(lat1R) * math.cos(lat2R) * math.cos(dLonR);
    final double bearing = _toDeg(math.atan2(y, x));
    return (bearing + 360) % 360;
  }

  // ── Elevation angle ──────────────────────────────────────────────────────────

  /// Shooting angle in degrees between two points at different elevations.
  /// [distanceMeters] is horizontal distance, [elevationDiffMeters] is
  /// (target elevation − shooter elevation).
  static double shootingAngleDeg(
    double distanceMeters,
    double elevationDiffMeters,
  ) {
    if (distanceMeters == 0) return 0;
    return _toDeg(math.atan2(elevationDiffMeters, distanceMeters));
  }

  // ── Unit conversions ─────────────────────────────────────────────────────────

  /// Metres → yards.
  static double metersToYards(double meters) => meters * 1.0936132983;

  /// Yards → metres.
  static double yardsToMeters(double yards) => yards * 0.9144;

  /// Feet → metres.
  static double feetToMeters(double feet) => feet * 0.3048;

  /// Metres → feet.
  static double metersToFeet(double meters) => meters * 3.2808398950;

  /// Miles per hour → metres per second.
  static double mphToMs(double mph) => mph * 0.44704;

  /// Metres per second → miles per hour.
  static double msToMph(double ms) => ms / 0.44704;

  /// Feet per second → metres per second.
  static double fpsToMs(double fps) => fps * 0.3048;

  /// Metres per second → feet per second.
  static double msToFps(double ms) => ms / 0.3048;

  /// Celsius → Fahrenheit.
  static double celsiusToFahrenheit(double c) => c * 9 / 5 + 32;

  /// Fahrenheit → Celsius.
  static double fahrenheitToCelsius(double f) => (f - 32) * 5 / 9;

  /// Grains → kilograms.
  static double grainsToKg(double grains) => grains * 6.479891e-5;

  /// Inches of mercury → pascals.
  static double inHgToPascals(double inHg) => inHg * 3386.389;

  /// hPa → inches of mercury.
  static double hPaToInHg(double hPa) => hPa * 0.02952998;

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static double _toRad(double deg) => deg * math.pi / 180.0;
  static double _toDeg(double rad) => rad * 180.0 / math.pi;
}
