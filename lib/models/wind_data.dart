/// Wind vector: speed and meteorological bearing (direction wind blows FROM).
class WindVector {
  /// Wind speed in km/h.
  final double speedKmh;

  /// Meteorological bearing in degrees (0 = from north, 90 = from east).
  /// This is the direction the wind is coming FROM.
  final double bearingDeg;

  const WindVector({required this.speedKmh, required this.bearingDeg});

  /// Direction the wind is blowing TOWARDS (opposite of bearing).
  double get towardsDeg => (bearingDeg + 180) % 360;
}

/// Abstract wind field — returns a wind vector for any geographic coordinate.
/// Phase 1: uniform field. Phase 2: grid-based from Open-Meteo.
abstract class WindField {
  const WindField();

  WindVector getWind(double lat, double lon);
}

/// Uniform wind field — same wind everywhere. Used for Phase 1 hardcoded
/// values and as a fallback.
class UniformWindField extends WindField {
  final WindVector wind;

  const UniformWindField(this.wind);

  /// Default: 20 km/h from the southwest (225°).
  factory UniformWindField.defaultWind() =>
      const UniformWindField(WindVector(speedKmh: 20, bearingDeg: 225));

  @override
  WindVector getWind(double lat, double lon) => wind;
}
