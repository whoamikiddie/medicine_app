package com.example.medicine_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

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
    }
}
