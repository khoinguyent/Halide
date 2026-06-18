import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'image_cache_utils.dart';

/// Persists `{ rollId: { imageKey: pathRelativeToDocuments } }` so local files stay
/// tied to stable DB image ids even when R2 URLs change.
class LocalImagePathIndex {
  LocalImagePathIndex._();
  static final instance = LocalImagePathIndex._();

  static const _fileName = 'halide_roll_image_paths.json';

  Map<String, Map<String, String>> _rolls = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File(p.join(dir.path, _fileName));
      if (!await f.exists()) return;
      final text = await f.readAsString();
      if (text.trim().isEmpty) return;
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return;
      final rollsJson = decoded['rolls'];
      if (rollsJson is! Map<String, dynamic>) return;
      for (final e in rollsJson.entries) {
        final inner = e.value;
        if (inner is Map<String, dynamic>) {
          _rolls[e.key] = inner.map((k, v) => MapEntry(k, v.toString()));
        }
      }
    } catch (e) {
      debugPrint('[ImagePathIndex] load failed: $e');
    }
  }

  Future<void> _persist() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File(p.join(dir.path, _fileName));
    final payload = const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'rolls': _rolls,
    });
    await f.writeAsString(payload, flush: true);
  }

  Future<void> put(String rollId, String imageKey, String pathRelativeToDocuments) async {
    await _ensureLoaded();
    _rolls.putIfAbsent(rollId, () => {});
    _rolls[rollId]![imageKey] = pathRelativeToDocuments;
    await _persist();
  }

  Future<String?> resolveAbsolute(String rollId, String imageKey, String documentsDirPath) async {
    await _ensureLoaded();
    final rel = _rolls[rollId]?[imageKey];
    if (rel == null || rel.isEmpty) return null;
    final abs = p.isAbsolute(rel) ? rel : p.join(documentsDirPath, rel);
    final file = File(abs);
    if (!await file.exists()) {
      return null;
    }
    if (!await isPlausibleImageCacheFile(file)) {
      return null;
    }
    return abs;
  }

  Future<void> removeKey(String rollId, String imageKey) async {
    await _ensureLoaded();
    _rolls[rollId]?.remove(imageKey);
    if (_rolls[rollId]?.isEmpty ?? false) {
      _rolls.remove(rollId);
    }
    await _persist();
  }

  /// Removes all keys for [rollId] that start with [prefix] (e.g. `lab:`).
  Future<void> removeKeysWithPrefix(String rollId, String prefix) async {
    await _ensureLoaded();
    final m = _rolls[rollId];
    if (m == null || m.isEmpty) return;
    final toRemove = m.keys.where((k) => k.startsWith(prefix)).toList();
    for (final k in toRemove) {
      m.remove(k);
    }
    if (m.isEmpty) {
      _rolls.remove(rollId);
    }
    await _persist();
  }

  /// Gyro-scan keys `gyro:0` … sorted by numeric suffix.
  Future<List<(int index, String key, String relativePath)>> listGyroEntriesSorted(String rollId) async {
    await _ensureLoaded();
    final m = _rolls[rollId];
    if (m == null || m.isEmpty) return [];
    final out = <(int, String, String)>[];
    for (final e in m.entries) {
      if (!e.key.startsWith('gyro:')) continue;
      final suffix = e.key.substring(5);
      if (suffix.contains('_')) continue;
      final n = int.tryParse(suffix);
      if (n == null) continue;
      out.add((n, e.key, e.value));
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return out;
  }

  /// Lab-import keys `lab:0` … sorted by numeric suffix. Values are paths relative to app documents.
  Future<List<(int index, String key, String relativePath)>> listLabEntriesSorted(String rollId) async {
    await _ensureLoaded();
    final m = _rolls[rollId];
    if (m == null || m.isEmpty) return [];
    final out = <(int, String, String)>[];
    for (final e in m.entries) {
      if (!e.key.startsWith('lab:')) continue;
      final n = int.tryParse(e.key.substring(4));
      if (n == null) continue;
      out.add((n, e.key, e.value));
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return out;
  }
}
