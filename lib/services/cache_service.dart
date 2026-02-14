import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medicine.dart';

/// Local cache for medicines and adherence data.
/// Enables instant UI loading and offline mode.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sp async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ─── Keys ──────────────────────────────────────────────────────────

  String _medicinesKey(String userId) => 'cached_medicines_$userId';
  String _adherenceKey(String userId) => 'cached_adherence_$userId';
  String _adherenceDateKey(String userId) => 'cached_adherence_date_$userId';
  static const _dailySummaryKey = 'daily_summary_enabled';

  // ─── Medicines ─────────────────────────────────────────────────────

  /// Save medicines list to local cache.
  Future<void> cacheMedicines(String userId, List<Medicine> medicines) async {
    try {
      final sp = await _sp;
      final jsonList = medicines.map((m) => jsonEncode(m.toJson())).toList();
      await sp.setStringList(_medicinesKey(userId), jsonList);
      debugPrint('[Cache] Saved ${medicines.length} medicines');
    } catch (e) {
      debugPrint('[Cache] Error saving medicines: $e');
    }
  }

  /// Load medicines from local cache. Returns null if nothing cached.
  Future<List<Medicine>?> getCachedMedicines(String userId) async {
    try {
      final sp = await _sp;
      final jsonList = sp.getStringList(_medicinesKey(userId));
      if (jsonList == null || jsonList.isEmpty) return null;

      final medicines = jsonList.map((jsonStr) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return Medicine.fromJson(map);
      }).toList();

      debugPrint('[Cache] Loaded ${medicines.length} medicines from cache');
      return medicines;
    } catch (e) {
      debugPrint('[Cache] Error loading medicines: $e');
      return null;
    }
  }

  // ─── Adherence ─────────────────────────────────────────────────────

  /// Save today's adherence map to local cache.
  Future<void> cacheAdherence(String userId, Map<String, bool> adherence) async {
    try {
      final sp = await _sp;
      final jsonStr = jsonEncode(adherence);
      final today = _todayKey();
      await sp.setString(_adherenceKey(userId), jsonStr);
      await sp.setString(_adherenceDateKey(userId), today);
      debugPrint('[Cache] Saved adherence (${adherence.length} entries)');
    } catch (e) {
      debugPrint('[Cache] Error saving adherence: $e');
    }
  }

  /// Load today's adherence from cache. Returns null if stale or missing.
  Future<Map<String, bool>?> getCachedAdherence(String userId) async {
    try {
      final sp = await _sp;
      final cachedDate = sp.getString(_adherenceDateKey(userId));
      if (cachedDate != _todayKey()) return null; // Stale data

      final jsonStr = sp.getString(_adherenceKey(userId));
      if (jsonStr == null) return null;

      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v == true));
    } catch (e) {
      debugPrint('[Cache] Error loading adherence: $e');
      return null;
    }
  }

  // ─── Daily Summary Preference ──────────────────────────────────────

  Future<bool> isDailySummaryEnabled() async {
    final sp = await _sp;
    return sp.getBool(_dailySummaryKey) ?? true; // Enabled by default
  }

  Future<void> setDailySummaryEnabled(bool enabled) async {
    final sp = await _sp;
    await sp.setBool(_dailySummaryKey, enabled);
  }

  // ─── Cleanup ───────────────────────────────────────────────────────

  Future<void> clearUserCache(String userId) async {
    final sp = await _sp;
    await sp.remove(_medicinesKey(userId));
    await sp.remove(_adherenceKey(userId));
    await sp.remove(_adherenceDateKey(userId));
    debugPrint('[Cache] Cleared cache for $userId');
  }

  // ─── Helpers ───────────────────────────────────────────────────────

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
