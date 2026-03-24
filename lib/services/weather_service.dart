import 'dart:convert';

import 'package:flutter/foundation.dart';
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

      debugPrint(
        '[WeatherService] ($lat, $lon): '
        '${current['temperature_2m']}°C, '
        '${current['relative_humidity_2m']}% RH, '
        '${current['surface_pressure']} hPa, '
        'wind ${current['wind_speed_10m']} km/h @ ${current['wind_direction_10m']}°',
      );

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

  /// Fetch hourly forecast wind for a specific future time at [lat]/[lon].
  /// Returns the closest hourly slot's wind speed (mph) and direction (°).
  /// Returns null on failure.
  Future<({double speedMph, double directionDeg})?> fetchWindForecast(
    double lat,
    double lon,
    DateTime targetUtc,
  ) async {
    try {
      final startDate = targetUtc.toIso8601String().substring(0, 10);
      // Fetch 2 days to cover timezone edge cases
      final endDate = targetUtc
          .add(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      final uri = Uri.parse(
        '$_baseUrl?latitude=$lat&longitude=$lon'
        '&hourly=wind_speed_10m,wind_direction_10m'
        '&start_date=$startDate&end_date=$endDate'
        '&timezone=UTC',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final hourly = json['hourly'] as Map<String, dynamic>;
      final times = (hourly['time'] as List).cast<String>();
      final speeds = (hourly['wind_speed_10m'] as List).cast<num>();
      final dirs = (hourly['wind_direction_10m'] as List).cast<num>();

      // Find the closest hour
      int bestIdx = 0;
      int bestDiff = 999999999;
      for (var i = 0; i < times.length; i++) {
        final t = DateTime.parse(times[i]);
        final diff = (t.difference(targetUtc).inMinutes).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          bestIdx = i;
        }
      }

      final speedMph = kmhToMph(speeds[bestIdx].toDouble());
      final dirDeg = dirs[bestIdx].toDouble();
      debugPrint(
        '[WeatherService] forecast ($lat, $lon) @ $targetUtc: '
        'wind ${speeds[bestIdx]} km/h ($speedMph mph) @ $dirDeg°',
      );
      return (speedMph: speedMph, directionDeg: dirDeg);
    } catch (e) {
      debugPrint('[WeatherService] forecast fetch failed: $e');
      return null;
    }
  }
}
