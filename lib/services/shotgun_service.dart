import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/calibration_record.dart';
import '../models/calibration_session.dart';

/// Persists shotgun calibration records and session history using Hive.
class ShotgunService {
  static const _boxName = 'shotgun_calibrations';
  static const _recordPrefix = 'cal_';
  static const _sessionPrefix = 'sessions_';

  Future<Box<String>> _openBox() => Hive.openBox<String>(_boxName);

  // ── Calibration Records ────────────────────────────────────────────

  Future<void> saveCalibration(String setupId, CalibrationRecord record) async {
    final box = await _openBox();
    await box.put('$_recordPrefix$setupId', jsonEncode(record.toJson()));
  }

  Future<CalibrationRecord?> loadCalibration(String setupId) async {
    final box = await _openBox();
    final raw = box.get('$_recordPrefix$setupId');
    if (raw == null) return null;
    return CalibrationRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> deleteCalibration(String setupId) async {
    final box = await _openBox();
    await box.delete('$_recordPrefix$setupId');
    await box.delete('$_sessionPrefix$setupId');
  }

  // ── Session History ────────────────────────────────────────────────

  Future<void> saveSession(String setupId, CalibrationSession session) async {
    final box = await _openBox();
    final key = '$_sessionPrefix$setupId';
    final raw = box.get(key);
    final List<Map<String, dynamic>> list;
    if (raw != null) {
      list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } else {
      list = [];
    }
    list.insert(0, session.toJson()); // newest first
    await box.put(key, jsonEncode(list));
  }

  Future<List<CalibrationSession>> loadSessions(String setupId) async {
    final box = await _openBox();
    final raw = box.get('$_sessionPrefix$setupId');
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(CalibrationSession.fromJson).toList();
  }
}
