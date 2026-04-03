import 'dart:ui';

import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Projects a geo line (shooter→target) to screen coordinates, handling the
/// Mapbox SDK returning (0,0) for off-screen points.
///
/// Strategy: sample the line at several parameter values.
/// Find two "good" projections (not clamped to origin) and extrapolate the
/// full line. If fewer than two good samples exist the line is fully off-screen.
class MapLineProjector {
  MapLineProjector._();

  /// Returns (shooterScreen, targetScreen) or null if the line is entirely
  /// off-screen and can't be projected.
  static Future<(Offset shooter, Offset target)?> project(
    MapboxMap map, {
    required double shooterLat,
    required double shooterLon,
    required double targetLat,
    required double targetLon,
  }) async {
    // Sample at 5 parameter values along the line.
    const tValues = [0.0, 0.125, 0.25, 0.5, 0.75, 0.875, 1.0];
    final samples = <(double t, Offset px)>[];

    for (final t in tValues) {
      final lat = shooterLat + t * (targetLat - shooterLat);
      final lon = shooterLon + t * (targetLon - shooterLon);
      final sc = await map.pixelForCoordinate(
        Point(coordinates: Position(lon, lat)),
      );
      final px = Offset(sc.x, sc.y);
      // (0,0) is the SDK's clamped value for off-screen points.
      // Accept it only if it's the sole value (unlikely coincidence).
      if (px.dx.abs() > 1 || px.dy.abs() > 1) {
        samples.add((t, px));
      }
    }

    if (samples.length < 2) return null; // fully off-screen

    // Pick two samples that are farthest apart in t-space for best accuracy.
    final a = samples.first;
    final b = samples.last;
    final dt = b.$1 - a.$1;
    if (dt.abs() < 0.001) return null;

    // Linear extrapolation: P(t) = a.px + ((t - a.t) / dt) * (b.px - a.px)
    final dir = (b.$2 - a.$2) / dt;
    final shooter = a.$2 + dir * (0.0 - a.$1);
    final target = a.$2 + dir * (1.0 - a.$1);

    return (shooter, target);
  }
}
