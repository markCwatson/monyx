import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/rifle_profile.dart';

/// Persists rifle profiles using Hive.
class ProfileService {
  static const _boxName = 'profiles';
  static const _activeKey = 'active_profile';

  Future<Box<String>> _openBox() => Hive.openBox<String>(_boxName);

  /// Save the active profile.
  Future<void> saveProfile(RifleProfile profile) async {
    final box = await _openBox();
    await box.put(_activeKey, jsonEncode(profile.toJson()));
  }

  /// Load the active profile. Returns null if none saved.
  Future<RifleProfile?> loadProfile() async {
    final box = await _openBox();
    final raw = box.get(_activeKey);
    if (raw == null) return null;
    return RifleProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Delete the active profile.
  Future<void> deleteProfile() async {
    final box = await _openBox();
    await box.delete(_activeKey);
  }
}
