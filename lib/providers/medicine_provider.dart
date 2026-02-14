import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/medicine.dart';
import '../services/cache_service.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';

class MedicineProvider extends ChangeNotifier {
  final MedicineService _service = MedicineService();
  final NotificationService _notificationService = NotificationService();
  final CacheService _cacheService = CacheService();
  List<Medicine> _medicines = [];
  Map<String, bool> _takenToday = {};
  String? _userId;
  StreamSubscription? _medicinesSub;
  bool _dailySummaryEnabled = true;
  bool _isLoading = true;

  bool get isDailySummaryEnabled => _dailySummaryEnabled;
  bool get isLoading => _isLoading;

  List<Medicine> get medicines => _medicines;
  Map<String, bool> get takenToday => _takenToday;

  /// Medicines with at least one missed dose today
  List<Medicine> get missedMedicines {
    final now = TimeOfDay.now();
    return activeMedicines.where((med) {
      return med.times.any((time) {
        final parts = time.split(':');
        final medTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
        final key = '${med.id}_$time';
        return _isTimePassed(medTime, now) && !(_takenToday[key] ?? false);
      });
    }).toList();
  }

  /// Active medicines: isActive AND not past endDate
  List<Medicine> get activeMedicines {
    final now = DateTime.now();
    return _medicines.where((m) {
      if (!m.isActive) return false;
      if (m.endDate != null && m.endDate!.isBefore(DateTime(now.year, now.month, now.day))) {
        return false; // Past end date
      }
      return true;
    }).toList();
  }

  /// Medicines that have completed their course (past endDate)
  List<Medicine> get completedMedicines {
    final now = DateTime.now();
    return _medicines.where((m) {
      return m.endDate != null && m.endDate!.isBefore(DateTime(now.year, now.month, now.day));
    }).toList();
  }

  int get totalMedicines => activeMedicines.length;

  /// Returns a list of all medicines active for today
  List<Medicine> get todaysMedicines => activeMedicines;

  /// Returns a map of time -> list of medicines scheduled at that time
  Map<String, List<Medicine>> get medicineTimes {
    final map = <String, List<Medicine>>{};
    for (final med in activeMedicines) {
      for (final time in med.times) {
        if (!map.containsKey(time)) {
          map[time] = [];
        }
        map[time]!.add(med);
      }
    }
    return map;
  }

  /// Total number of doses scheduled for today
  int get totalMedicinesToday {
    return activeMedicines.fold(0, (sum, med) => sum + med.times.length);
  }

  /// Total doses taken today
  int get takenCount => _takenToday.values.where((v) => v).length;

  int get takenTodayCount =>
      _takenToday.values.where((v) => v).length;

  int get missedTodayCount {
    final now = TimeOfDay.now();
    int missed = 0;
    for (final med in activeMedicines) {
      for (final time in med.times) {
        final parts = time.split(':');
        final medTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
        final key = '${med.id}_$time';
        if (_isTimePassed(medTime, now) && !(_takenToday[key] ?? false)) {
          missed++;
        }
      }
    }
    return missed;
  }

  double get adherencePercentage {
    if (activeMedicines.isEmpty) return 100.0;
    final totalDoses = activeMedicines.fold<int>(
      0,
      (sum, m) => sum + m.times.length,
    );
    if (totalDoses == 0) return 100.0;
    return (takenTodayCount / totalDoses * 100).clamp(0.0, 100.0);
  }

  bool _isTimePassed(TimeOfDay medTime, TimeOfDay now) {
    return medTime.hour < now.hour ||
        (medTime.hour == now.hour && medTime.minute <= now.minute);
  }

  bool isTaken(String medicineId, String time) {
    return _takenToday['${medicineId}_$time'] ?? false;
  }

  // ─── Initialize with user ID ──────────────────────────────────────

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _medicinesSub?.cancel();
    
    if (userId == null) {
      // Clear cache on logout
      if (_userId != null) _cacheService.clearUserCache(_userId!);
      _medicines = [];
      _takenToday = {};
      notifyListeners();
      return;
    }

    // 1. Load cached data immediately for instant UI
    _loadFromCache(userId);

    // 2. Load daily summary preference
    _loadDailySummaryPref();

    // 3. Listen to real-time medicine updates from Firestore
    _medicinesSub = _service.medicinesStream(userId).listen(
      (meds) {
        _medicines = meds;
        _isLoading = false;
        notifyListeners();

        // Cache the fresh data
        _cacheService.cacheMedicines(userId, meds);

        // Auto-schedule notifications for ALL active medicines
        _rescheduleAllNotifications();
      },
      onError: (e) {
        debugPrint('Medicine stream error: $e');
        // On error, cached data stays — UI remains functional
      },
    );

    // 4. Load today's adherence
    _loadTodayAdherence();
  }

  /// Load medicines and adherence from local cache for instant display.
  Future<void> _loadFromCache(String userId) async {
    final cachedMeds = await _cacheService.getCachedMedicines(userId);
    if (cachedMeds != null && cachedMeds.isNotEmpty && _medicines.isEmpty) {
      _medicines = cachedMeds;
      _isLoading = false;
      notifyListeners();
      debugPrint('[Provider] Loaded ${cachedMeds.length} medicines from cache');
    }

    final cachedAdherence = await _cacheService.getCachedAdherence(userId);
    if (cachedAdherence != null && _takenToday.isEmpty) {
      _takenToday = cachedAdherence;
      notifyListeners();
      debugPrint('[Provider] Loaded adherence from cache');
    }
  }

  Future<void> _loadDailySummaryPref() async {
    _dailySummaryEnabled = await _cacheService.isDailySummaryEnabled();
    notifyListeners();
  }

  Future<void> toggleDailySummary() async {
    _dailySummaryEnabled = !_dailySummaryEnabled;
    await _cacheService.setDailySummaryEnabled(_dailySummaryEnabled);
    notifyListeners();

    if (_dailySummaryEnabled) {
      _scheduleDailySummaryIfNeeded();
    } else {
      _notificationService.cancelDailySummary();
    }
  }

  void _scheduleDailySummaryIfNeeded() {
    if (_dailySummaryEnabled && activeMedicines.isNotEmpty) {
      _notificationService.scheduleDailySummary(activeMedicines);
    }
  }

  // ─── Reschedule notifications for all active medicines ────────────

  Future<void> _rescheduleAllNotifications() async {
    // Auto-deactivate expired medicines
    await _deactivateExpiredMedicines();

    final active = activeMedicines;
    if (active.isEmpty) {
      debugPrint('[Provider] No active medicines to schedule');
      return;
    }

    debugPrint('[Provider] ═══ Rescheduling ${active.length} active medicines ═══');

    int successCount = 0;
    int failCount = 0;

    for (final medicine in active) {
      try {
        await _notificationService.scheduleMedicineReminders(medicine);
        successCount++;
      } catch (e) {
        failCount++;
        debugPrint('[Provider] ✗ Failed to schedule ${medicine.name}: $e');
      }
    }

    // Cancel notifications for completed medicines
    for (final medicine in completedMedicines) {
      await _notificationService.cancelMedicineReminders(medicine.id);
    }

    // Schedule daily summary notification
    _scheduleDailySummaryIfNeeded();

    // Debug: Show all pending notifications
    final pendingCount = await _notificationService.debugPendingNotifications();

    debugPrint('[Provider] ═══ Scheduling Complete ═══');
    debugPrint('[Provider] ✓ Success: $successCount, ✗ Failed: $failCount');
    debugPrint('[Provider] Total pending notifications: $pendingCount');
    debugPrint('[Provider] ═══════════════════════════');
  }

  /// Auto-deactivate medicines past their endDate
  Future<void> _deactivateExpiredMedicines() async {
    if (_userId == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final medicine in _medicines) {
      if (medicine.isActive && medicine.endDate != null && medicine.endDate!.isBefore(today)) {
        try {
          await _service.toggleActive(_userId!, medicine.id, false);
          debugPrint('[Medicine] Auto-deactivated: ${medicine.name} (ended ${medicine.endDate})');
        } catch (e) {
          debugPrint('[Medicine] Failed to deactivate ${medicine.name}: $e');
        }
      }
    }
  }

  Future<void> _loadTodayAdherence() async {
    if (_userId == null) return;
    _takenToday = await _service.getTodayAdherence(_userId!);
    notifyListeners();

    // Cache adherence for offline use
    _cacheService.cacheAdherence(_userId!, _takenToday);
  }

  // ─── CRUD Operations ──────────────────────────────────────────────

  void toggleTaken(String medicineId, String time) {
    final key = '${medicineId}_$time';
    final newValue = !(_takenToday[key] ?? false);
    _takenToday[key] = newValue;
    notifyListeners();
    
    if (_userId != null) {
      _service.toggleTaken(_userId!, medicineId, time, newValue);
      // Update cached adherence
      _cacheService.cacheAdherence(_userId!, _takenToday);
    }
  }

  Future<void> addMedicine(Medicine medicine) async {
    try {
      await _service.addMedicine(medicine);
      // Real-time stream will update the list automatically
    } catch (e) {
      debugPrint('Error adding medicine: $e');
      rethrow;
    }
  }

  Future<void> removeMedicine(String id) async {
    if (_userId == null) return;
    try {
      await _service.deleteMedicine(_userId!, id);
    } catch (e) {
      debugPrint('Error removing medicine: $e');
      rethrow;
    }
  }

  Future<void> toggleActive(String id) async {
    if (_userId == null) return;
    final index = _medicines.indexWhere((m) => m.id == id);
    if (index != -1) {
      final newActive = !_medicines[index].isActive;
      try {
        await _service.toggleActive(_userId!, id, newActive);
      } catch (e) {
        debugPrint('Error toggling active: $e');
      }
    }
  }

  String generateId() => const Uuid().v4();

  // Group medicines by time period
  Map<String, List<MapEntry<Medicine, String>>> get groupedByPeriod {
    final Map<String, List<MapEntry<Medicine, String>>> groups = {
      'Morning': [],
      'Afternoon': [],
      'Evening': [],
    };

    for (final med in activeMedicines) {
      for (final time in med.times) {
        final hour = int.parse(time.split(':')[0]);
        final period = hour < 12
            ? 'Morning'
            : hour < 17
                ? 'Afternoon'
                : 'Evening';
        groups[period]!.add(MapEntry(med, time));
      }
    }
    return groups;
  }

  // For reports
  Future<List<Map<String, dynamic>>> getAdherenceHistory(int days) async {
    if (_userId == null) return [];
    return _service.getAdherenceHistory(_userId!, days);
  }

  @override
  void dispose() {
    _medicinesSub?.cancel();
    super.dispose();
  }
}
