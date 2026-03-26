class AppConfig {
  /// Loaded at compile time via --dart-define-from-file=.env
  static const String mapboxPublicToken = String.fromEnvironment(
    'MAPBOX_PUBLIC_TOKEN',
  );

  /// Mapbox tileset ID for the public/Crown land overlay.
  /// Set via --dart-define or .env after uploading the tileset to Mapbox Studio.
  /// Example: "yourusername.land_overlay"
  static const String landTilesetId = String.fromEnvironment(
    'LAND_TILESET_ID',
    defaultValue: '',
  );
}
