/// Application-wide constants for Monyx.
class AppConstants {
  AppConstants._();

  static const String appName = 'Monyx';

  // ── Network ──────────────────────────────────────────────────────────────────
  static const String openMeteoBaseUrl = 'https://api.open-meteo.com/v1';

  // ── Map ───────────────────────────────────────────────────────────────────────
  static const String mapboxStyleUri = 'mapbox://styles/mapbox/outdoors-v12';
  static const double defaultZoom = 14.0;
  static const double pinDropZoom = 16.0;

  // ── Ballistics ───────────────────────────────────────────────────────────────
  /// Standard sea-level pressure (inches of mercury).
  static const double standardPressureInHg = 29.92;

  /// Standard temperature at sea level (°F).
  static const double standardTempF = 59.0;

  /// Standard altitude (feet).
  static const double standardAltitudeFt = 0.0;

  /// Standard speed of sound at sea level (fps).
  static const double standardSpeedOfSoundFps = 1116.45;

  // ── Physics ───────────────────────────────────────────────────────────────────
  /// Earth's mean radius (metres).
  static const double earthRadiusMeters = 6371000.0;

  /// Standard gravity (m/s²).
  static const double gravity = 9.80665;

  // ── UI ────────────────────────────────────────────────────────────────────────
  /// How often (ms) to poll for location updates.
  static const int locationIntervalMs = 2000;
}
