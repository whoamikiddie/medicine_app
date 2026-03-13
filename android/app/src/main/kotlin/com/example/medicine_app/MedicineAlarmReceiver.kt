package com.example.medicine_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

class MedicineAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("MedicineAlarm", "Alarm triggered!")
        
        val medicineId = intent.getStringExtra("medicine_id") ?: return
        val medicineName = intent.getStringExtra("medicine_name") ?: "Medicine"
        val dosage = intent.getStringExtra("dosage") ?: ""
        val time = intent.getStringExtra("time") ?: ""
        val foodInstruction = intent.getStringExtra("food_instruction") ?: ""
        
        Log.d("MedicineAlarm", "Sending notification for: $medicineName at $time")
        
        // Send notification
        NotificationHelper.sendMedicineNotification(
            context,
            medicineId,
            medicineName,
            dosage,
            time,
            foodInstruction
        )

        // Re-schedule the same alarm for tomorrow so it repeats daily
        if (time.isNotEmpty()) {
            rescheduleForTomorrow(context, medicineId, medicineName, dosage, time, foodInstruction)
        }
    }

    private fun rescheduleForTomorrow(
        context: Context,
        medicineId: String,
        medicineName: String,
        dosage: String,
        time: String,
        foodInstruction: String
    ) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            val parts = time.split(":")
            val hour = parts[0].toInt()
            val minute = parts[1].toInt()

            // Schedule for tomorrow at the same time
            val calendar = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            val nextIntent = Intent(context, MedicineAlarmReceiver::class.java).apply {
                putExtra("medicine_id", medicineId)
                putExtra("medicine_name", medicineName)
                putExtra("dosage", dosage)
                putExtra("time", time)
                putExtra("food_instruction", foodInstruction)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                medicineId.hashCode(),
                nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        calendar.timeInMillis,
                        pendingIntent
                    )
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }
            Log.d("MedicineAlarm", "Re-scheduled alarm for $medicineName tomorrow at $time")
        } catch (e: Exception) {
            Log.e("MedicineAlarm", "Error re-scheduling alarm: ${e.message}")
        }
    }
}
