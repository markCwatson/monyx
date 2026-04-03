import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/saved_line.dart';

class LineService {
  static const _boxName = 'saved_lines';
  static const _listKey = 'lines';

  Future<Box<String>> _openBox() => Hive.openBox<String>(_boxName);

  Future<List<SavedLine>> loadAll() async {
    final box = await _openBox();
    final raw = box.get(_listKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(SavedLine.fromJson).toList();
  }

  Future<void> save(SavedLine line) async {
    final lines = await loadAll();
    lines.removeWhere((l) => l.id == line.id);
    lines.add(line);
    await _persist(lines);
  }

  Future<void> delete(String lineId) async {
    final lines = await loadAll();
    lines.removeWhere((l) => l.id == lineId);
    await _persist(lines);
  }

  Future<void> _persist(List<SavedLine> lines) async {
    final box = await _openBox();
    await box.put(_listKey, jsonEncode(lines.map((l) => l.toJson()).toList()));
  }
}
