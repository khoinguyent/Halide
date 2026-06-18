import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/roll.dart';
import '../../../models/roll_status.dart';
import '../../../services/roll_service.dart';

/// Tracks gyro-scan sessions that have not been explicitly finished yet.
class GyroScanSessionService {
  GyroScanSessionService._();
  static final instance = GyroScanSessionService._();

  static const _prefsKey = 'gyro_scan_unfinished_v1';

  Future<Set<String>> unfinishedRollIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw);
      if (list is! List) return {};
      return list.whereType<String>().where((id) => id.isNotEmpty).toSet();
    } catch (e) {
      debugPrint('[GyroScanSession] parse failed: $e');
      return {};
    }
  }

  Future<void> markUnfinished(String rollId) async {
    final ids = await unfinishedRollIds();
    if (ids.contains(rollId)) return;
    ids.add(rollId);
    await _save(ids);
  }

  Future<void> clearUnfinished(String rollId) async {
    final ids = await unfinishedRollIds();
    if (!ids.remove(rollId)) return;
    await _save(ids);
  }

  Future<void> _save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(ids.toList()));
  }

  /// Rolls left mid-scan must stay at lab even if frame uploads ran on an older build.
  Future<bool> reconcileScannedRolls({
    required List<Roll> rolls,
    required String token,
    required RollService rollService,
  }) async {
    final pending = await unfinishedRollIds();
    if (pending.isEmpty) return false;

    var changed = false;
    for (final roll in rolls) {
      if (!pending.contains(roll.id)) continue;
      if (roll.status != RollStatus.scanned) continue;
      try {
        await rollService.pauseGyroScanSession(token, roll.id);
        changed = true;
        debugPrint('[GyroScanSession] reverted roll ${roll.id} to lab (unfinished scan)');
      } catch (e) {
        debugPrint('[GyroScanSession] reconcile failed for ${roll.id}: $e');
      }
    }
    return changed;
  }
}
