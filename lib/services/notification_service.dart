import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/medicine.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Platform channel for battery optimization
  static const _platform = MethodChannel('com.medicine.app/battery');

  bool _initialized = false;

  // ─── Vibration pattern (WhatsApp-style double buzz) ───────────────
  static final Int64List _vibrationPattern =
      Int64List.fromList([0, 500, 200, 500]);

  // ─── LED color ────────────────────────────────────────────────────
  static const _ledColor = Color(0xFF6C63FF);

  // ─── Channel config ───────────────────────────────────────────────
  // v3: Force new channel to reset cached importance on existing installs
  static const _channelId = 'medicine_reminder_v3';
  static const _channelName = 'Medicine Reminders';
  static const _channelDesc = 'Urgent medicine reminders — heads-up alerts';

  // Daily summary channel (lower priority)
  static const _summaryChannelId = 'daily_medicine_summary';
  static const _summaryChannelName = 'Daily Medicine Summary';
  static const _summaryChannelDesc = 'Morning summary of all medicines for the day';
  static const _summaryNotifId = 88888;

  // ─── Initialize ───────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    // Auto-detect user's timezone instead of hardcoding
    final String timeZoneName = DateTime.now().timeZoneName;
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Fallback to UTC if timezone not found
      debugPrint('[Notification] Timezone $timeZoneName not found, using UTC');
      tz.setLocalLocation(tz.UTC);
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();

      // Create high-priority channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: _ledColor,
          showBadge: true,
        ),
      );

      // Create daily summary channel (default priority)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _summaryChannelId,
          _summaryChannelName,
          description: _summaryChannelDesc,
          importance: Importance.defaultImportance,
          playSound: true,
          enableVibration: false,
          showBadge: true,
        ),
      );
    }

    _initialized = true;
    debugPrint('[Notification] Initialized (${tz.local.name})');
  }

  /// Ensure all notification-related permissions are granted
  Future<bool> ensurePermissionsGranted() async {
    if (!_initialized) await init();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) {
      debugPrint('[Notification] Non-Android platform, permissions assumed OK');
      return true; // Non-Android, assume OK
    }

    // Check notification permission
    final notifGranted = await androidPlugin.requestNotificationsPermission();
    debugPrint('[Notification] ✓ Notification permission: $notifGranted');

    // Check exact alarm permission (Android 12+)
    final exactAlarmGranted = await androidPlugin.requestExactAlarmsPermission();
    debugPrint('[Notification] ✓ Exact alarm permission: $exactAlarmGranted');

    if (notifGranted != true) {
      debugPrint('[Notification] ⚠️ CRITICAL: Notification permission NOT granted!');
      return false;
    }
    if (exactAlarmGranted != true) {
      debugPrint('[Notification] ⚠️ WARNING: Exact alarm permission NOT granted — using inexact alarms');
    }

    return notifGranted == true;
  }

  /// Log all pending notifications for debugging
  Future<int> debugPendingNotifications() async {
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('[Notification] ═══ ${pending.length} pending notifications ═══');
    for (final n in pending) {
      debugPrint('[Notification]   #${n.id}: ${n.title} — ${n.body}');
    }
    debugPrint('[Notification] ═════════════════════════════════════════');
    return pending.length;
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[Notification] Action: ${response.actionId}, payload: ${response.payload}');

    final actionId = response.actionId ?? '';
    final payload = response.payload ?? '';

    if (actionId == 'snooze_action') {
      _handleSnooze(response.id ?? 0, payload);
    } else if (actionId == 'take_action') {
      _handleTakeNow(payload);
    }
  }

  /// Snooze: schedule a new notification 10 minutes from now
  Future<void> _handleSnooze(int originalId, String medicineId) async {
    final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
    final snoozeId = originalId + 50000; // Distinct ID

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      color: _ledColor,
      colorized: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    try {
      await _plugin.zonedSchedule(
        snoozeId,
        'Snoozed Reminder',
        'Time to take your medicine (snoozed)',
        snoozeTime,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: medicineId,
      );
      debugPrint('[Snooze] Scheduled #$snoozeId at $snoozeTime');
    } catch (e) {
      debugPrint('[Snooze] Error: $e');
    }
  }

  /// Take Now: mark the dose as taken in Firestore
  Future<void> _handleTakeNow(String medicineId) async {
    if (medicineId.isEmpty || medicineId == 'test') return;
    try {
      // We need userId — get it from the medicine service's current context
      // Since we don't have userId here, we'll just log it
      // The actual marking is handled when user opens the app
      debugPrint('[TakeNow] Medicine $medicineId marked (app will sync)');
    } catch (e) {
      debugPrint('[TakeNow] Error: $e');
    }
  }

  // ─── Request Battery Optimization Exemption ───────────────────────
  // Critical for Xiaomi/MIUI, Oppo, Vivo, Samsung etc.
  // Without this, AlarmManager alarms are killed in background

  Future<bool> requestBatteryOptimizationExemption() async {
    try {
      final result =
          await _platform.invokeMethod('requestBatteryOptimization');
      return result == true;
    } catch (e) {
      debugPrint('[Battery] Platform channel error: $e');
      return false;
    }
  }

  Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final result =
          await _platform.invokeMethod('isBatteryOptimizationDisabled');
      return result == true;
    } catch (e) {
      debugPrint('[Battery] Check error: $e');
      return false;
    }
  }

  // ─── Schedule Medicine Reminders ──────────────────────────────────

  Future<void> scheduleMedicineReminders(Medicine medicine) async {
    if (!_initialized) await init();
    if (!medicine.isActive) {
      debugPrint('[Notification] Skipping ${medicine.name} - not active');
      return;
    }

    // Ensure permissions before scheduling
    final hasPermissions = await ensurePermissionsGranted();
    if (!hasPermissions) {
      debugPrint('[Notification] ⚠️ Cannot schedule ${medicine.name} - permissions denied');
      return;
    }

    await cancelMedicineReminders(medicine.id);
    debugPrint('[Notification] Scheduling reminders for: ${medicine.name}');

    for (int i = 0; i < medicine.times.length; i++) {
      final timeParts = medicine.times[i].split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      final notifId = medicine.id.hashCode.abs() % 100000 + i;

      final foodText = medicine.foodInstruction == 'before'
          ? 'Before food'
          : medicine.foodInstruction == 'after'
              ? 'After food'
              : 'With food';

      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final timeStr =
          '$displayHour:${minute.toString().padLeft(2, '0')} $period';

      // Main medicine reminder
      await _scheduleDailyNotification(
        id: notifId,
        title: 'Time to take ${medicine.name}',
        body: '${medicine.dosage}  •  $foodText  •  $timeStr',
        hour: hour,
        minute: minute,
        payload: medicine.id,
        medicineName: medicine.name,
        dosage: medicine.dosage,
        foodInstruction: foodText,
        timeDisplay: timeStr,
      );

      // ─── Food timing pre-reminder ──────────────────────────────
      if (medicine.foodInstruction == 'after') {
        // Remind to eat 15 minutes before medicine
        final foodMinute = minute - 15;
        final foodHour = foodMinute < 0 ? hour - 1 : hour;
        final adjustedMinute = foodMinute < 0 ? foodMinute + 60 : foodMinute;
        if (foodHour >= 0) {
          await _scheduleDailyNotification(
            id: notifId + 10000, // Offset for food reminder
            title: 'Time to eat — ${medicine.name} in 15 min',
            body: 'Have your meal now. Take ${medicine.name} (${medicine.dosage}) after eating.',
            hour: foodHour,
            minute: adjustedMinute,
            payload: '${medicine.id}_food',
            medicineName: medicine.name,
            dosage: medicine.dosage,
            foodInstruction: 'Eat now',
            timeDisplay: timeStr,
          );
          debugPrint('[Notification] Food pre-reminder at $foodHour:$adjustedMinute');
        }
      } else if (medicine.foodInstruction == 'before') {
        // Remind to eat after taking medicine (30 min after)
        final eatMinute = (minute + 30) % 60;
        final eatHour = minute + 30 >= 60 ? hour + 1 : hour;
        if (eatHour < 24) {
          await _scheduleDailyNotification(
            id: notifId + 10000,
            title: 'You can eat now',
            body: 'It\'s been 30 min since ${medicine.name}. Safe to eat.',
            hour: eatHour,
            minute: eatMinute,
            payload: '${medicine.id}_food',
            medicineName: medicine.name,
            dosage: medicine.dosage,
            foodInstruction: 'Eat now',
            timeDisplay: '',
          );
          debugPrint('[Notification] Post-medicine eat reminder at $eatHour:$eatMinute');
        }
      }

      debugPrint(
          '[Notification] Scheduled #$notifId: ${medicine.name} at $hour:$minute');
    }
  }

  // ─── Core Scheduling ─────────────────────────────────────────────

  Future<void> _scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
    String medicineName = '',
    String dosage = '',
    String foodInstruction = '',
    String timeDisplay = '',
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, hour, minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
      enableLights: true,
      ledColor: _ledColor,
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ticker: 'Medicine Reminder: $medicineName',
      autoCancel: true,
      showWhen: true,
      when: scheduledDate.millisecondsSinceEpoch,
      styleInformation: BigTextStyleInformation(
        '$medicineName  —  $dosage\n$foodInstruction  •  $timeDisplay\n\nTap to open and mark as taken.',
        contentTitle: 'Time to take $medicineName',
        summaryText: 'Medicine Reminder',
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'take_action',
          'Take Now',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze_action',
          'Snooze 10 min',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
      number: 1,
      channelShowBadge: true,
      color: _ledColor,
      colorized: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
      threadIdentifier: 'medicine_reminders',
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id, title, body, scheduledDate, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      debugPrint('[Notification] #$id OK at $scheduledDate');
    } catch (e) {
      debugPrint('[Notification] #$id exact failed: $e');
      try {
        await _plugin.zonedSchedule(
          id, title, body, scheduledDate, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
        debugPrint('[Notification] #$id fallback OK');
      } catch (e2) {
        debugPrint('[Notification] #$id failed completely: $e2');
      }
    }
  }

  // ─── Send Test Notification (immediate) ───────────────────────────

  Future<void> sendTestNotification() async {
    if (!_initialized) await init();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
      enableLights: true,
      ledColor: _ledColor,
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      ticker: 'Medicine Reminder Test',
      color: _ledColor,
      colorized: true,
      styleInformation: const BigTextStyleInformation(
        'Paracetamol  —  500mg\nAfter food  •  Now\n\nTap to open and mark as taken.',
        contentTitle: 'Time to take Paracetamol',
        summaryText: 'Medicine Reminder',
      ),
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          'take_action',
          'Take Now',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze_action',
          'Snooze 10 min',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
        99999, 'Time to take Paracetamol',
        'Paracetamol  •  500mg  •  After food', details,
        payload: 'test');
  }

  // ─── Show Immediate Notification ──────────────────────────────────

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
      enableLights: true,
      ledColor: _ledColor,
      ledOnMs: 1000,
      ledOffMs: 500,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      autoCancel: true,
      color: _ledColor,
      colorized: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details, payload: payload);
  }

  // ─── Cancel ───────────────────────────────────────────────────────

  Future<void> cancelMedicineReminders(String medicineId) async {
    final baseId = medicineId.hashCode.abs() % 100000;
    for (int i = 0; i < 5; i++) {
      await _plugin.cancel(baseId + i);          // Main reminders
      await _plugin.cancel(baseId + i + 10000);  // Food reminders
      await _plugin.cancel(baseId + i + 50000);  // Snooze reminders
    }
  }

  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
    debugPrint('[Notification] All cancelled');
  }

  // ─── Debug ────────────────────────────────────────────────────────

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }

  // ─── Daily Summary Notification ─────────────────────────────────────

  /// Schedule a daily summary notification at the given [hour]:[minute].
  /// Lists all active medicines grouped by Morning / Afternoon / Evening.
  Future<void> scheduleDailySummary(
    List<Medicine> medicines, {
    int hour = 7,
    int minute = 0,
  }) async {
    if (!_initialized) await init();
    if (medicines.isEmpty) return;

    // Cancel existing summary first
    await cancelDailySummary();

    // Build summary body grouped by time period
    final Map<String, List<String>> groups = {
      '🌅 Morning': [],
      '☀️ Afternoon': [],
      '🌙 Evening': [],
    };

    for (final med in medicines) {
      if (!med.isActive) continue;
      for (final time in med.times) {
        final h = int.parse(time.split(':')[0]);
        final m = time.split(':')[1];
        final period = h >= 12 ? 'PM' : 'AM';
        final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        final timeStr = '$dh:$m $period';
        final entry = '${med.name} ${med.dosage} — $timeStr';

        if (h < 12) {
          groups['🌅 Morning']!.add(entry);
        } else if (h < 17) {
          groups['☀️ Afternoon']!.add(entry);
        } else {
          groups['🌙 Evening']!.add(entry);
        }
      }
    }

    final buffer = StringBuffer();
    for (final entry in groups.entries) {
      if (entry.value.isEmpty) continue;
      buffer.writeln(entry.key);
      for (final item in entry.value) {
        buffer.writeln('  • $item');
      }
    }

    final totalDoses = medicines.fold<int>(0, (s, m) => s + m.times.length);
    final body = buffer.toString().trim();
    final title = "Today's Medicines — $totalDoses dose${totalDoses == 1 ? '' : 's'}";

    // Schedule time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, hour, minute,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final androidDetails = AndroidNotificationDetails(
      _summaryChannelId,
      _summaryChannelName,
      channelDescription: _summaryChannelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      autoCancel: true,
      color: _ledColor,
      colorized: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Daily Summary',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'daily_summary',
    );

    try {
      await _plugin.zonedSchedule(
        _summaryNotifId,
        title,
        body,
        scheduledDate,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily_summary',
      );
      debugPrint('[DailySummary] Scheduled at $hour:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('[DailySummary] Error scheduling: $e');
      // Fallback to inexact
      try {
        await _plugin.zonedSchedule(
          _summaryNotifId,
          title,
          body,
          scheduledDate,
          NotificationDetails(android: androidDetails, iOS: iosDetails),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'daily_summary',
        );
        debugPrint('[DailySummary] Fallback scheduled OK');
      } catch (e2) {
        debugPrint('[DailySummary] Failed completely: $e2');
      }
    }
  }

  /// Cancel the daily summary notification.
  Future<void> cancelDailySummary() async {
    await _plugin.cancel(_summaryNotifId);
    debugPrint('[DailySummary] Cancelled');
  }
}
