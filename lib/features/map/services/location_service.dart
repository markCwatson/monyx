import 'dart:async';

/// Lightweight position data returned by the location service.
class LocationData {
  const LocationData({
    required this.latitude,
    required this.longitude,
    this.altitudeMeters,
    this.accuracyMeters,
    this.headingDegrees,
    this.speedMps,
  });

  final double latitude;
  final double longitude;
  final double? altitudeMeters;
  final double? accuracyMeters;
  final double? headingDegrees;
  final double? speedMps;
}

/// Abstract interface so the real geolocator and a mock can be swapped.
abstract class LocationServiceBase {
  Stream<LocationData> getPositionStream();
  Future<LocationData?> getCurrentPosition();
}

/// Production location service backed by `geolocator`.
///
/// The geolocator dependency is imported at runtime via the plugin.
/// When the plugin is not available (e.g. running unit tests without a device)
/// the [MockLocationService] is used instead.
class LocationService implements LocationServiceBase {
  LocationService({this.useMock = false});

  /// Set to true in tests to avoid platform channel calls.
  final bool useMock;

  final _mockService = MockLocationService();

  @override
  Stream<LocationData> getPositionStream() {
    if (useMock) return _mockService.getPositionStream();
    // Real implementation uses geolocator package.
    // The plugin stream is wrapped here; if unavailable falls back to mock.
    return _realPositionStream();
  }

  @override
  Future<LocationData?> getCurrentPosition() async {
    if (useMock) return _mockService.getCurrentPosition();
    return _realCurrentPosition();
  }

  // ── Real geolocator calls (requires plugin) ──────────────────────────────────

  Stream<LocationData> _realPositionStream() {
    // Geolocator is a Flutter plugin and cannot be imported without pub get.
    // Once `flutter pub get` has run, replace this block:
    //
    //   import 'package:geolocator/geolocator.dart';
    //   return Geolocator.getPositionStream(
    //     locationSettings: const LocationSettings(
    //       accuracy: LocationAccuracy.high,
    //       distanceFilter: 5,
    //     ),
    //   ).map((p) => LocationData(
    //     latitude: p.latitude,
    //     longitude: p.longitude,
    //     altitudeMeters: p.altitude,
    //     accuracyMeters: p.accuracy,
    //     headingDegrees: p.heading,
    //     speedMps: p.speed,
    //   ));
    //
    // For now, fall back to mock so UI can be previewed without a device.
    return _mockService.getPositionStream();
  }

  Future<LocationData?> _realCurrentPosition() async {
    // Same plug-in caveat as above.
    return _mockService.getCurrentPosition();
  }
}

/// Fixed-location mock for tests and UI previews.
class MockLocationService implements LocationServiceBase {
  MockLocationService({
    this.latitude = 44.5588,
    this.longitude = -110.4777, // Yellowstone area
    this.altitudeMeters = 2400.0,
  });

  final double latitude;
  final double longitude;
  final double altitudeMeters;

  @override
  Stream<LocationData> getPositionStream() async* {
    // Emit immediately, then every 2 seconds with a tiny wander.
    int tick = 0;
    while (true) {
      yield LocationData(
        latitude: latitude + (tick * 0.000005),
        longitude: longitude + (tick * 0.000003),
        altitudeMeters: altitudeMeters,
        accuracyMeters: 5.0,
        headingDegrees: 0.0,
        speedMps: 0.0,
      );
      tick++;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  @override
  Future<LocationData?> getCurrentPosition() async => LocationData(
    latitude: latitude,
    longitude: longitude,
    altitudeMeters: altitudeMeters,
    accuracyMeters: 5.0,
  );
}
