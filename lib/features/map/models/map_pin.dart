import 'package:flutter/foundation.dart';

/// Type/category of a map pin.
enum PinType {
  waypoint,
  target,
  camp,
  other;

  String get displayName {
    switch (this) {
      case PinType.waypoint:
        return 'Waypoint';
      case PinType.target:
        return 'Target';
      case PinType.camp:
        return 'Camp';
      case PinType.other:
        return 'Other';
    }
  }

  String get icon {
    switch (this) {
      case PinType.waypoint:
        return '📍';
      case PinType.target:
        return '🎯';
      case PinType.camp:
        return '🏕';
      case PinType.other:
        return '📌';
    }
  }
}

/// A user-placed point of interest on the map.
@immutable
class MapPin {
  const MapPin({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.createdAt,
    this.elevationMeters,
    this.label,
    this.notes,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double? elevationMeters;
  final String? label;
  final String? notes;
  final PinType type;
  final DateTime createdAt;

  factory MapPin.fromJson(Map<String, dynamic> json) => MapPin(
    id: json['id'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    elevationMeters: (json['elevationMeters'] as num?)?.toDouble(),
    label: json['label'] as String?,
    notes: json['notes'] as String?,
    type: PinType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => PinType.waypoint,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'elevationMeters': elevationMeters,
    'label': label,
    'notes': notes,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
  };

  MapPin copyWith({
    String? id,
    double? latitude,
    double? longitude,
    double? elevationMeters,
    String? label,
    String? notes,
    PinType? type,
    DateTime? createdAt,
  }) => MapPin(
    id: id ?? this.id,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    elevationMeters: elevationMeters ?? this.elevationMeters,
    label: label ?? this.label,
    notes: notes ?? this.notes,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MapPin && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MapPin(id: $id, lat: $latitude, lon: $longitude, type: ${type.name})';
}
