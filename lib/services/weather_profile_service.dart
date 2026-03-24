import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/weather_profile.dart';

/// Persists weather profiles for offline wind animation using Hive.
class WeatherProfileService {
  static const _boxName = 'weather_profiles';
  static const _listKey = 'profiles';

  Future<Box<String>> _openBox() => Hive.openBox<String>(_boxName);

  /// Load all saved weather profiles, newest first.
  Future<List<WeatherProfile>> loadAll() async {
    final box = await _openBox();
    final raw = box.get(_listKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(WeatherProfile.fromJson).toList();
  }

  /// Save a new weather profile.
  Future<void> save(WeatherProfile profile) async {
    final all = await loadAll();
    all.insert(0, profile);
    await _saveAll(all);
  }

  /// Delete a weather profile by ID.
  Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((p) => p.id == id);
    await _saveAll(all);
  }

  Future<void> _saveAll(List<WeatherProfile> profiles) async {
    final box = await _openBox();
    final json = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await box.put(_listKey, json);
  }
}
