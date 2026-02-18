import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BackgroundAlarmService {
  static final BackgroundAlarmService _instance = BackgroundAlarmService._internal();
  factory BackgroundAlarmService() => _instance;
  BackgroundAlarmService._internal();

  static const _platform = MethodChannel('com.medicine.app/alarm');

  /// Schedule an exact alarm for a medicine reminder
  Future<bool> scheduleAlarm({
    required String medicineId,
    required String medicineName,
    required String dosage,
    required String time, // Format: "HH:mm"
    required String foodInstruction,
  }) async {
    try {
      debugPrint('📱 [BackgroundAlarm] Scheduling alarm for $medicineName at $time');
      
      final result = await _platform.invokeMethod('scheduleAlarm', {
        'medicineId': medicineId,
        'medicineName': medicineName,
        'dosage': dosage,
        'time': time,
        'foodInstruction': foodInstruction,
      });
      
      debugPrint('📱 [BackgroundAlarm] ✅ Alarm scheduled successfully');
      return result == true;
    } catch (e) {
      debugPrint('📱 [BackgroundAlarm] ❌ Error scheduling alarm: $e');
      return false;
    }
  }

  /// Cancel an alarm for a specific medicine
  Future<bool> cancelAlarm(String medicineId) async {
    try {
      debugPrint('📱 [BackgroundAlarm] Cancelling alarm for medicine: $medicineId');
      
      final result = await _platform.invokeMethod('cancelAlarm', {
        'medicineId': medicineId,
      });
      
      debugPrint('📱 [BackgroundAlarm] ✅ Alarm cancelled');
      return result == true;
    } catch (e) {
      debugPrint('📱 [BackgroundAlarm] ❌ Error cancelling alarm: $e');
      return false;
    }
  }

  /// Check if the app can schedule exact alarms (Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    try {
      final result = await _platform.invokeMethod('canScheduleExactAlarms');
      debugPrint('📱 [BackgroundAlarm] Can schedule exact alarms: $result');
      return result == true;
    } catch (e) {
      debugPrint('📱 [BackgroundAlarm] Error checking alarm permission: $e');
      return false;
    }
  }
}
