import 'package:flutter/foundation.dart';

import 'map_pin.dart';

/// Immutable state snapshot for the map feature.
@immutable
class MapState {
  const MapState({
    this.userLatitude,
    this.userLongitude,
    this.userElevationMeters,
    this.pins = const [],
    this.selectedPin,
    this.isOffline = false,
    this.showLandOverlay = false,
  });

  final double? userLatitude;
  final double? userLongitude;
  final double? userElevationMeters;
  final List<MapPin> pins;
  final MapPin? selectedPin;
  final bool isOffline;
  final bool showLandOverlay;

  bool get hasLocation => userLatitude != null && userLongitude != null;

  MapState copyWith({
    double? userLatitude,
    double? userLongitude,
    double? userElevationMeters,
    List<MapPin>? pins,
    MapPin? selectedPin,
    bool clearSelectedPin = false,
    bool? isOffline,
    bool? showLandOverlay,
  }) => MapState(
    userLatitude: userLatitude ?? this.userLatitude,
    userLongitude: userLongitude ?? this.userLongitude,
    userElevationMeters: userElevationMeters ?? this.userElevationMeters,
    pins: pins ?? this.pins,
    selectedPin: clearSelectedPin ? null : selectedPin ?? this.selectedPin,
    isOffline: isOffline ?? this.isOffline,
    showLandOverlay: showLandOverlay ?? this.showLandOverlay,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapState &&
          userLatitude == other.userLatitude &&
          userLongitude == other.userLongitude &&
          userElevationMeters == other.userElevationMeters &&
          pins == other.pins &&
          selectedPin == other.selectedPin &&
          isOffline == other.isOffline &&
          showLandOverlay == other.showLandOverlay;

  @override
  int get hashCode => Object.hash(
    userLatitude,
    userLongitude,
    userElevationMeters,
    pins,
    selectedPin,
    isOffline,
    showLandOverlay,
  );
}
