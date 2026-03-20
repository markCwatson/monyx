import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches elevation data from Open-Meteo elevation API.
class ElevationService {
  static const _baseUrl = 'https://api.open-meteo.com/v1/elevation';

  /// Get elevation in meters for a single point. Returns 0 on failure.
  Future<double> getElevationMeters(double lat, double lon) async {
    try {
      final uri = Uri.parse('$_baseUrl?latitude=$lat&longitude=$lon');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return 0;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final elevList = json['elevation'] as List<dynamic>;
      if (elevList.isEmpty) return 0;
      return (elevList.first as num).toDouble();
    } catch (_) {
      return 0;
    }
  }

  /// Get elevation in feet for a single point.
  Future<double> getElevationFeet(double lat, double lon) async {
    final meters = await getElevationMeters(lat, lon);
    return meters * 3.28084;
  }

  /// Get elevations for two points. Returns (elev1Ft, elev2Ft).
  Future<(double, double)> getElevationPairFeet(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?latitude=$lat1,$lat2&longitude=$lon1,$lon2',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return (0.0, 0.0);

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final elevList = json['elevation'] as List<dynamic>;
      if (elevList.length < 2) return (0.0, 0.0);
      final e1 = (elevList[0] as num).toDouble() * 3.28084;
      final e2 = (elevList[1] as num).toDouble() * 3.28084;
      return (e1, e2);
    } catch (_) {
      return (0.0, 0.0);
    }
  }
}
