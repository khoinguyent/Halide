import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_config.dart';
import 'gyro_scan_cache_service.dart';

/// Pending gyro-scan upload task.
class GyroScanSyncTask {
  final String rollId;
  final int frameNumber;
  final String localRawPath;

  const GyroScanSyncTask({
    required this.rollId,
    required this.frameNumber,
    required this.localRawPath,
  });

  Map<String, dynamic> toJson() => {
        'roll_id': rollId,
        'frame_number': frameNumber,
        'local_raw_path': localRawPath,
      };

  factory GyroScanSyncTask.fromJson(Map<String, dynamic> json) {
    return GyroScanSyncTask(
      rollId: json['roll_id'] as String? ?? '',
      frameNumber: (json['frame_number'] as num?)?.toInt() ?? 0,
      localRawPath: json['local_raw_path'] as String? ?? '',
    );
  }
}

/// Background queue that uploads gyro-scanned frames to the server.
class GyroScanSyncService {
  GyroScanSyncService._();
  static final instance = GyroScanSyncService._();

  static const _prefsKey = 'gyro_scan_sync_queue_v1';
  bool _processing = false;

  Future<List<GyroScanSyncTask>> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => GyroScanSyncTask.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.rollId.isNotEmpty && t.localRawPath.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[GyroScanSync] queue parse failed: $e');
      return [];
    }
  }

  Future<void> _saveQueue(List<GyroScanSyncTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  Future<void> enqueue(GyroScanSyncTask task) async {
    final queue = await _loadQueue();
    queue.removeWhere(
      (t) => t.rollId == task.rollId && t.frameNumber == task.frameNumber,
    );
    queue.add(task);
    await _saveQueue(queue);
    debugPrint('[GyroScanSync] enqueued frame ${task.frameNumber} roll=${task.rollId}');
    // Uploads are flushed only when the user taps Finish scanning.
  }

  /// Upload all pending frames for [rollId]. Called from Finish scanning.
  Future<void> processQueueForRoll(
    String rollId, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (_processing) return;
    _processing = true;
    try {
      var queue = await _loadQueue();
      final pending = queue.where((t) => t.rollId == rollId).toList();
      final total = pending.length;
      onProgress?.call(0, total);
      var done = 0;
      for (final task in pending) {
        final ok = await _uploadOne(task);
        queue = await _loadQueue();
        if (ok) {
          queue.removeWhere(
            (t) => t.rollId == task.rollId && t.frameNumber == task.frameNumber,
          );
          await _saveQueue(queue);
          await GyroScanCacheService.instance.deleteRawAfterSync(task.localRawPath);
          done++;
          onProgress?.call(done, total);
        } else {
          break;
        }
      }
    } finally {
      _processing = false;
    }
  }

  Future<bool> _uploadOne(GyroScanSyncTask task) async {
    final file = File(task.localRawPath);
    if (!await file.exists()) {
      debugPrint('[GyroScanSync] raw missing, dropping task: ${task.localRawPath}');
      return true;
    }

    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      debugPrint('[GyroScanSync] no auth token');
      return false;
    }

    try {
      final length = await file.length();
      const maxBytes = 15 * 1024 * 1024;
      if (length > maxBytes) {
        debugPrint('[GyroScanSync] file too large, dropping');
        return true;
      }

      final uri = Uri.parse(
        '${AppConfig.apiUrl}/rolls/${task.rollId}/frames/${task.frameNumber}/scan',
      );
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          task.localRawPath,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[GyroScanSync] uploaded frame ${task.frameNumber} roll=${task.rollId}');
        return true;
      }
      debugPrint('[GyroScanSync] upload failed HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('[GyroScanSync] upload error: $e');
      return false;
    }
  }
}
