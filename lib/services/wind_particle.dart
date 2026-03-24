/// A single wind particle with screen-space position and lifetime.
class Particle {
  double x;
  double y;
  double prevX;
  double prevY;
  double age; // seconds since birth
  double maxAge; // total lifetime in seconds

  Particle({required this.x, required this.y, this.age = 0, this.maxAge = 5})
    : prevX = x,
      prevY = y;

  /// Normalised age: 0 at birth, 1 at death.
  double get t => (age / maxAge).clamp(0.0, 1.0);

  /// Opacity envelope: fade in during first 15%, fade out during last 25%.
  double get opacity {
    if (t < 0.15) return t / 0.15;
    if (t > 0.75) return (1.0 - t) / 0.25;
    return 1.0;
  }
}
