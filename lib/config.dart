class AppConfig {
  /// Loaded at compile time via --dart-define-from-file=.env
  static const String mapboxPublicToken = String.fromEnvironment(
    'MAPBOX_PUBLIC_TOKEN',
  );
}
