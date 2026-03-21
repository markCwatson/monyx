import 'package:equatable/equatable.dart';

import 'detection.dart';

/// Type of animal trace being identified.
enum TraceType { footprint, feces }

/// A saved track identification result.
class TrackResult extends Equatable {
  final String id;
  final String imagePath;
  final TraceType traceType;
  final List<Detection> detections;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;

  /// Original image dimensions for mapping bbox coordinates.
  final int imageWidth;
  final int imageHeight;

  const TrackResult({
    required this.id,
    required this.imagePath,
    required this.traceType,
    required this.detections,
    required this.timestamp,
    required this.imageWidth,
    required this.imageHeight,
    this.latitude,
    this.longitude,
  });

  /// The top detection by confidence, or null if none.
  Detection? get topDetection => detections.isEmpty ? null : detections.first;

  /// Display name for the trace type.
  String get traceLabel => switch (traceType) {
    TraceType.footprint => 'Footprint',
    TraceType.feces => 'Scat',
  };

  /// Formats a species name from model class (e.g. "sus_scrofa" → "Sus Scrofa").
  static String formatSpeciesName(String raw) {
    return raw
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'traceType': traceType.name,
    'detections': detections.map((d) => d.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory TrackResult.fromJson(Map<String, dynamic> json) => TrackResult(
    id: json['id'] as String,
    imagePath: json['imagePath'] as String,
    traceType: TraceType.values.byName(json['traceType'] as String),
    detections: (json['detections'] as List)
        .map((d) => Detection.fromJson(d as Map<String, dynamic>))
        .toList(),
    timestamp: DateTime.parse(json['timestamp'] as String),
    imageWidth: json['imageWidth'] as int,
    imageHeight: json['imageHeight'] as int,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
  );

  @override
  List<Object?> get props => [id];
}
