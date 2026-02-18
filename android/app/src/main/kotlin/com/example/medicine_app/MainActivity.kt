package com.example.medicine_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val BATTERY_CHANNEL = "com.medicine.app/battery"
    private val ALARM_CHANNEL = "com.medicine.app/alarm"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBatteryOptimization" -> {
                    requestIgnoreBatteryOptimization()
                    result.success(true)
                }
                "isBatteryOptimizationDisabled" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Alarm scheduling channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val medicineId = call.argument<String>("medicineId") ?: ""
                    val medicineName = call.argument<String>("medicineName") ?: ""
                    val dosage = call.argument<String>("dosage") ?: ""
                    val time = call.argument<String>("time") ?: ""
                    val foodInstruction = call.argument<String>("foodInstruction") ?: ""
                    
                    scheduleExactAlarm(medicineId, medicineName, dosage, time, foodInstruction)
                    result.success(true)
                }
                "cancelAlarm" -> {
                    val medicineId = call.argument<String>("medicineId") ?: ""
                    cancelAlarm(medicineId)
                    result.success(true)
                }
                "canScheduleExactAlarms" -> {
                    result.success(canScheduleExactAlarms())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun scheduleExactAlarm(
        medicineId: String,
        medicineName: String,
        dosage: String,
        time: String,
        foodInstruction: String
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // Parse time (format: "HH:mm")
        val parts = time.split(":")
        val hour = parts[0].toInt()
        val minute = parts[1].toInt()
        
        // Create calendar for alarm time
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            
            // If time has passed today, schedule for tomorrow
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }
        
        // Create intent for alarm receiver
        val intent = Intent(this, MedicineAlarmReceiver::class.java).apply {
            putExtra("medicine_id", medicineId)
            putExtra("medicine_name", medicineName)
            putExtra("dosage", dosage)
            putExtra("time", time)
            putExtra("food_instruction", foodInstruction)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            medicineId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Schedule exact alarm
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                    Log.d("MainActivity", "Scheduled exact alarm for $medicineName at $time")
                } else {
                    Log.w("MainActivity", "Cannot schedule exact alarms - permission denied")
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
                Log.d("MainActivity", "Scheduled alarm for $medicineName at $time")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error scheduling alarm: ${e.message}")
        }
    }

    private fun cancelAlarm(medicineId: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, MedicineAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            medicineId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        Log.d("MainActivity", "Cancelled alarm for medicine: $medicineId")
    }

    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun requestIgnoreBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = packageName
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        }
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true // Pre-M doesn't have battery optimization
    }
}
