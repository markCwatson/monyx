import 'package:equatable/equatable.dart';

enum WeatherSource { live, cached, estimated }

class WeatherData extends Equatable {
  final double temperatureF;
  final double humidityPercent;
  final double pressureInHg; // station pressure
  final double windSpeedMph;
  final double windDirectionDeg; // meteorological "from" direction, 0=N
  final double altitudeFt; // station altitude above sea level
  final WeatherSource source;

  const WeatherData({
    required this.temperatureF,
    required this.humidityPercent,
    required this.pressureInHg,
    required this.windSpeedMph,
    required this.windDirectionDeg,
    this.altitudeFt = 0,
    required this.source,
  });

  /// ICAO standard atmosphere defaults
  factory WeatherData.standard() => const WeatherData(
    temperatureF: 59.0,
    humidityPercent: 50.0,
    pressureInHg: 29.92,
    windSpeedMph: 0,
    windDirectionDeg: 0,
    source: WeatherSource.estimated,
  );

  @override
  List<Object?> get props => [
    temperatureF,
    humidityPercent,
    pressureInHg,
    windSpeedMph,
    windDirectionDeg,
    altitudeFt,
    source,
  ];
}
