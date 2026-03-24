import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/poi.dart';

/// Persists point-of-interest pins using Hive.
class PoiService {
  static const _boxName = 'poi_pins';
  static const _listKey = 'pins';

  Future<Box<String>> _openBox() => Hive.openBox<String>(_boxName);

  /// App-local directory for POI photos.
  Future<Directory> _photosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/pois');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Copy a photo to permanent storage and return the dest path.
  Future<String> savePhoto(String sourcePath, String poiId) async {
    final dir = await _photosDir();
    final ext = sourcePath.contains('.')
        ? sourcePath.substring(sourcePath.lastIndexOf('.'))
        : '.jpg';
    final destPath = '${dir.path}/$poiId$ext';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Delete a photo file if it exists.
  Future<void> deletePhoto(String? photoPath) async {
    if (photoPath == null) return;
    final file = File(photoPath);
    if (await file.exists()) await file.delete();
  }

  /// Load all saved POIs.
  Future<List<Poi>> loadAll() async {
    final box = await _openBox();
    final raw = box.get(_listKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Poi.fromJson).toList();
  }

  /// Save a new POI.
  Future<void> save(Poi poi) async {
    final all = await loadAll();
    all.insert(0, poi);
    await _saveAll(all);
  }

  /// Update an existing POI (matched by id).
  Future<void> update(Poi poi) async {
    final all = await loadAll();
    final idx = all.indexWhere((p) => p.id == poi.id);
    if (idx >= 0) {
      all[idx] = poi;
      await _saveAll(all);
    }
  }

  /// Delete a POI by ID.
  Future<void> delete(String id) async {
    final all = await loadAll();
    final match = all.where((p) => p.id == id).firstOrNull;
    if (match != null) await deletePhoto(match.photoPath);
    all.removeWhere((p) => p.id == id);
    await _saveAll(all);
  }

  Future<void> _saveAll(List<Poi> pois) async {
    final box = await _openBox();
    final json = jsonEncode(pois.map((p) => p.toJson()).toList());
    await box.put(_listKey, json);
  }
}
