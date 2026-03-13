package com.example.medicine_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object NotificationHelper {
    private const val CHANNEL_ID = "medicine_reminders"
    private const val CHANNEL_NAME = "Medicine Reminders"
    
    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = "Notifications for medicine reminders"
                enableVibration(true)
                enableLights(true)
                
                // Set alarm sound
                val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
                
                setSound(alarmSound, audioAttributes)
                setBypassDnd(true)
            }
            
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    fun sendMedicineNotification(
        context: Context,
        medicineId: String,
        medicineName: String,
        dosage: String,
        time: String,
        foodInstruction: String
    ) {
        createNotificationChannel(context)
        
        // Full-screen intent to show alarm over lock screen
        val fullScreenIntent = Intent(context, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("medicine_id", medicineId)
            putExtra("medicine_name", medicineName)
            putExtra("dosage", dosage)
            putExtra("time", time)
            putExtra("food_instruction", foodInstruction)
        }
        
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            medicineId.hashCode(),
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Regular tap intent
        val tapIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("medicine_id", medicineId)
        }
        
        val tapPendingIntent = PendingIntent.getActivity(
            context,
            medicineId.hashCode() + 1,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Build notification text
        val foodText = when (foodInstruction) {
            "before" -> "Take before food"
            "after" -> "Take after food"
            "with" -> "Take with food"
            else -> ""
        }
        
        val contentText = buildString {
            append(dosage)
            if (foodText.isNotEmpty()) {
                append(" | $foodText")
            }
            append(" | $time")
        }
        
        // Alarm sound
        val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        
        // Build notification
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Time to take $medicineName")
            .setContentText(contentText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(contentText))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false) // Don't dismiss on tap
            .setOngoing(true) // Make it persistent
            .setContentIntent(tapPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true) // Show over lock screen
            .setSound(alarmSound)
            .setVibrate(longArrayOf(0, 1000, 500, 1000, 500, 1000))
            .setLights(0xFF0000FF.toInt(), 1000, 1000)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
        
        // Show notification
        with(NotificationManagerCompat.from(context)) {
            notify(medicineId.hashCode(), notification)
        }
        
        android.util.Log.d("NotificationHelper", "Sent ALARM notification for $medicineName at $time")
    }
}
