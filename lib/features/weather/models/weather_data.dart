/// Current weather conditions at a specific location.
class WeatherData {
  const WeatherData({
    required this.temperatureCelsius,
    required this.windSpeedMs,
    required this.windDirectionDeg,
    required this.pressureHpa,
    required this.humidityPercent,
    required this.fetchedAt,
    required this.latitude,
    required this.longitude,
    this.densityAltitudeFeet,
  });

  final double temperatureCelsius;
  final double windSpeedMs;
  final double windDirectionDeg;
  final double pressureHpa;
  final double humidityPercent;
  final double? densityAltitudeFeet;
  final DateTime fetchedAt;
  final double latitude;
  final double longitude;

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
    temperatureCelsius: (json['temperatureCelsius'] as num).toDouble(),
    windSpeedMs: (json['windSpeedMs'] as num).toDouble(),
    windDirectionDeg: (json['windDirectionDeg'] as num).toDouble(),
    pressureHpa: (json['pressureHpa'] as num).toDouble(),
    humidityPercent: (json['humidityPercent'] as num).toDouble(),
    densityAltitudeFeet: (json['densityAltitudeFeet'] as num?)?.toDouble(),
    fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'temperatureCelsius': temperatureCelsius,
    'windSpeedMs': windSpeedMs,
    'windDirectionDeg': windDirectionDeg,
    'pressureHpa': pressureHpa,
    'humidityPercent': humidityPercent,
    'densityAltitudeFeet': densityAltitudeFeet,
    'fetchedAt': fetchedAt.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
  };

  WeatherData copyWith({
    double? temperatureCelsius,
    double? windSpeedMs,
    double? windDirectionDeg,
    double? pressureHpa,
    double? humidityPercent,
    double? densityAltitudeFeet,
    DateTime? fetchedAt,
    double? latitude,
    double? longitude,
  }) => WeatherData(
    temperatureCelsius: temperatureCelsius ?? this.temperatureCelsius,
    windSpeedMs: windSpeedMs ?? this.windSpeedMs,
    windDirectionDeg: windDirectionDeg ?? this.windDirectionDeg,
    pressureHpa: pressureHpa ?? this.pressureHpa,
    humidityPercent: humidityPercent ?? this.humidityPercent,
    densityAltitudeFeet: densityAltitudeFeet ?? this.densityAltitudeFeet,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
  );

  @override
  String toString() =>
      'WeatherData(${temperatureCelsius.toStringAsFixed(1)}°C, '
      '${windSpeedMs.toStringAsFixed(1)} m/s @ ${windDirectionDeg.toStringAsFixed(0)}°, '
      '${pressureHpa.toStringAsFixed(1)} hPa)';
}
