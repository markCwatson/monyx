import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/track_result.dart';

/// Persists track identification results using Hive + local image files.
class TrackService {
  static const _boxName = 'track_results';
  static const _listKey = 'results';

  Future<Box<String>> _openBox() => Hive.openBox<String>(_boxName);

  /// Save a track result. Copies the image to app documents.
  Future<TrackResult> saveResult(TrackResult result) async {
    debugPrint('[TrackService] saveResult called for id=${result.id}');
    final appDir = await getApplicationDocumentsDirectory();
    final tracksDir = Directory('${appDir.path}/tracks');
    if (!tracksDir.existsSync()) {
      tracksDir.createSync(recursive: true);
    }

    // Copy image to permanent storage
    final imgPath = result.imagePath;
    final ext = imgPath.contains('.')
        ? imgPath.substring(imgPath.lastIndexOf('.'))
        : '.jpg';
    final destPath = '${tracksDir.path}/${result.id}$ext';
    debugPrint('[TrackService] Copying image from $imgPath to $destPath');
    await File(result.imagePath).copy(destPath);

    final saved = TrackResult(
      id: result.id,
      imagePath: destPath,
      traceType: result.traceType,
      detections: result.detections,
      timestamp: result.timestamp,
      imageWidth: result.imageWidth,
      imageHeight: result.imageHeight,
      latitude: result.latitude,
      longitude: result.longitude,
    );

    // Persist metadata
    final results = await _loadAll();
    results.insert(0, saved);
    await _saveAll(results);
    debugPrint('[TrackService] Saved. Total results now: ${results.length}');

    return saved;
  }

  /// Load all saved results, newest first.
  Future<List<TrackResult>> loadResults() async {
    return _loadAll();
  }

  /// Delete a saved result by ID.
  Future<void> deleteResult(String id) async {
    final results = await _loadAll();
    final idx = results.indexWhere((r) => r.id == id);
    if (idx == -1) return;

    final result = results[idx];

    // Delete image file
    final file = File(result.imagePath);
    if (await file.exists()) {
      await file.delete();
    }

    results.removeAt(idx);
    await _saveAll(results);
  }

  // ── Private ────────────────────────────────────────────────────────

  Future<List<TrackResult>> _loadAll() async {
    final box = await _openBox();
    final raw = box.get(_listKey);
    debugPrint(
      '[TrackService] _loadAll: raw=${raw == null ? 'null' : '${raw.length} chars'}',
    );
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    debugPrint('[TrackService] _loadAll: parsed ${list.length} results');
    return list.map(TrackResult.fromJson).toList();
  }

  Future<void> _saveAll(List<TrackResult> results) async {
    final box = await _openBox();
    final json = jsonEncode(results.map((r) => r.toJson()).toList());
    await box.put(_listKey, json);
  }
}
