import 'dart:convert';

import 'package:http/http.dart' as http;

import '../ballistics/conversions.dart';
import '../models/weather_data.dart';

/// Fetches current weather from Open-Meteo (free, no API key).
class WeatherService {
  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetch current weather at a given lat/lon.
  /// Returns standard atmosphere defaults on failure.
  Future<WeatherData> fetchWeather(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?latitude=$lat&longitude=$lon'
        '&current=temperature_2m,relative_humidity_2m,surface_pressure,wind_speed_10m,wind_direction_10m',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return WeatherData.standard();
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;

      return WeatherData(
        temperatureF: celsiusToFahrenheit(
          (current['temperature_2m'] as num).toDouble(),
        ),
        humidityPercent: (current['relative_humidity_2m'] as num).toDouble(),
        pressureInHg: hpaToInHg(
          (current['surface_pressure'] as num).toDouble(),
        ),
        windSpeedMph: kmhToMph((current['wind_speed_10m'] as num).toDouble()),
        windDirectionDeg: (current['wind_direction_10m'] as num).toDouble(),
        source: WeatherSource.live,
      );
    } catch (_) {
      return WeatherData.standard();
    }
  }
}
