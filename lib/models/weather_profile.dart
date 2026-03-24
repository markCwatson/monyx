import 'package:equatable/equatable.dart';

/// A saved weather snapshot for offline wind animation.
class WeatherProfile extends Equatable {
  final String id;

  /// Human-readable label (e.g. "Cabin — Mar 24, 6:00 AM").
  final String label;

  final double latitude;
  final double longitude;

  /// Wind speed in mph.
  final double windSpeedMph;

  /// Meteorological bearing in degrees (direction wind blows FROM).
  final double windDirectionDeg;

  /// The time this weather is for (current time for "Now", forecast time for "Later").
  final DateTime targetTime;

  /// When this profile was fetched.
  final DateTime fetchedAt;

  const WeatherProfile({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.windSpeedMph,
    required this.windDirectionDeg,
    required this.targetTime,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'latitude': latitude,
    'longitude': longitude,
    'windSpeedMph': windSpeedMph,
    'windDirectionDeg': windDirectionDeg,
    'targetTime': targetTime.toIso8601String(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory WeatherProfile.fromJson(Map<String, dynamic> json) => WeatherProfile(
    id: json['id'] as String,
    label: json['label'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    windSpeedMph: (json['windSpeedMph'] as num).toDouble(),
    windDirectionDeg: (json['windDirectionDeg'] as num).toDouble(),
    targetTime: DateTime.parse(json['targetTime'] as String),
    fetchedAt: DateTime.parse(json['fetchedAt'] as String),
  );

  @override
  List<Object?> get props => [id];

  /// Cardinal/intercardinal compass label for a meteorological bearing.
  static String compassLabel(double deg) {
    const labels = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final i = ((deg % 360 + 22.5) / 45).floor() % 8;
    return labels[i];
  }
}
