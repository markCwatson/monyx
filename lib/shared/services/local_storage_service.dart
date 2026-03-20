import 'dart:convert';

/// Simple key-value local storage backed by JSON.
/// This is a lightweight wrapper used by features that don't need a full
/// relational database (Drift is used for structured data).
///
/// In production, swap the in-memory map with a real persistence mechanism
/// (e.g. `shared_preferences` or a file on disk via `path_provider`).
class LocalStorageService {
  LocalStorageService();

  final Map<String, String> _store = {};

  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  Future<String?> read(String key) async => _store[key];

  Future<void> delete(String key) async => _store.remove(key);

  Future<void> writeJson(String key, Map<String, dynamic> data) =>
      write(key, jsonEncode(data));

  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = await read(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> list) =>
      write(key, jsonEncode(list));

  Future<List<Map<String, dynamic>>?> readList(String key) async {
    final raw = await read(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return null;
  }

  Future<void> clear() async => _store.clear();
}
