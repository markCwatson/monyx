import 'package:equatable/equatable.dart';

/// Types of map pins the user can drop.
enum PoiType {
  campsite,
  treeStand,
  trailCam,
  waterSource,
  foodPlot,
  parking,
  custom,
}

extension PoiTypeLabel on PoiType {
  String get label => switch (this) {
    PoiType.campsite => 'Campsite',
    PoiType.treeStand => 'Tree Stand',
    PoiType.trailCam => 'Trail Cam',
    PoiType.waterSource => 'Water Source',
    PoiType.foodPlot => 'Food Plot',
    PoiType.parking => 'Parking',
    PoiType.custom => 'Custom',
  };
}

/// A saved point-of-interest pin on the map.
class Poi extends Equatable {
  final String id;
  final PoiType type;
  final double latitude;
  final double longitude;
  final String? note;
  final String? photoPath;
  final DateTime timestamp;

  const Poi({
    required this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.note,
    this.photoPath,
  });

  Poi copyWith({String? note, String? photoPath, bool clearPhoto = false}) =>
      Poi(
        id: id,
        type: type,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        note: note ?? this.note,
        photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'latitude': latitude,
    'longitude': longitude,
    'note': note,
    'photoPath': photoPath,
    'timestamp': timestamp.toIso8601String(),
  };

  factory Poi.fromJson(Map<String, dynamic> json) => Poi(
    id: json['id'] as String,
    type: PoiType.values.byName(json['type'] as String),
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    note: json['note'] as String?,
    photoPath: json['photoPath'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );

  @override
  List<Object?> get props => [id];
}
