import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/rifle_profile.dart';

/// Persists rifle profiles using Hive.
///
/// Free users: single profile only (index 0).
/// Pro users: unlimited profiles with an active selection.
class ProfileService {
  static const _boxName = 'profiles';
  static const _activeKey = 'active_profile'; // legacy single-profile key
  static const _listKey = 'profile_list';
  static const _activeIndexKey = 'active_index';

  Future<Box<String>> _openBox() => Hive.openBox<String>(_boxName);

  // ── Multi-profile API ──────────────────────────────────────────────

  /// Load all saved profiles. Migrates the legacy single profile if needed.
  Future<List<RifleProfile>> loadProfiles() async {
    final box = await _openBox();
    final raw = box.get(_listKey);
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(RifleProfile.fromJson).toList();
    }

    // Migrate legacy single-profile data
    final legacy = box.get(_activeKey);
    if (legacy != null) {
      final profile = RifleProfile.fromJson(
        jsonDecode(legacy) as Map<String, dynamic>,
      );
      await _saveList(box, [profile]);
      await box.put(_activeIndexKey, '0');
      return [profile];
    }

    return [];
  }

  /// Save the full profile list.
  Future<void> saveProfiles(List<RifleProfile> profiles) async {
    final box = await _openBox();
    await _saveList(box, profiles);
  }

  /// Get the active profile index (defaults to 0).
  Future<int> loadActiveIndex() async {
    final box = await _openBox();
    final raw = box.get(_activeIndexKey);
    return raw != null ? int.parse(raw) : 0;
  }

  /// Set the active profile index.
  Future<void> saveActiveIndex(int index) async {
    final box = await _openBox();
    await box.put(_activeIndexKey, index.toString());
  }

  Future<void> _saveList(Box<String> box, List<RifleProfile> profiles) async {
    final json = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await box.put(_listKey, json);
  }

  // ── Legacy single-profile API (still used by free tier) ────────────

  /// Save the active profile (convenience — overwrites index 0).
  Future<void> saveProfile(RifleProfile profile) async {
    final profiles = await loadProfiles();
    if (profiles.isEmpty) {
      profiles.add(profile);
    } else {
      final idx = await loadActiveIndex();
      if (idx < profiles.length) {
        profiles[idx] = profile;
      } else {
        profiles.add(profile);
      }
    }
    await saveProfiles(profiles);
  }

  /// Load the active profile. Returns null if none saved.
  Future<RifleProfile?> loadProfile() async {
    final profiles = await loadProfiles();
    if (profiles.isEmpty) return null;
    final idx = await loadActiveIndex();
    return idx < profiles.length ? profiles[idx] : profiles.first;
  }

  /// Delete the active profile.
  Future<void> deleteProfile() async {
    final profiles = await loadProfiles();
    if (profiles.isEmpty) return;
    final idx = await loadActiveIndex();
    if (idx < profiles.length) {
      profiles.removeAt(idx);
    }
    await saveProfiles(profiles);
    if (profiles.isNotEmpty) {
      await saveActiveIndex(0);
    }
  }
}
