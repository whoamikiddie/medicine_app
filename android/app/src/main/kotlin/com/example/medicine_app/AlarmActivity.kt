package com.example.medicine_app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AlarmActivity : Activity() {

    private var vibrator: Vibrator? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show over lock screen and turn on screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        // Dismiss keyguard so alarm shows on top
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            keyguardManager.requestDismissKeyguard(this, null)
        }

        setContentView(R.layout.activity_alarm)

        // Get medicine details from intent
        val medicineName = intent.getStringExtra("medicine_name") ?: "Medicine"
        val dosage = intent.getStringExtra("dosage") ?: ""
        val time = intent.getStringExtra("time") ?: ""
        val foodInstruction = intent.getStringExtra("food_instruction") ?: ""

        // Set medicine name
        findViewById<TextView>(R.id.medicine_name).text = medicineName

        // Set dosage
        if (dosage.isNotEmpty()) {
            findViewById<TextView>(R.id.dosage_text).text = dosage
        } else {
            findViewById<LinearLayout>(R.id.dosage_row).visibility = View.GONE
        }

        // Set food instruction
        val foodText = when (foodInstruction) {
            "before" -> "Take before food"
            "after"  -> "Take after food"
            "with"   -> "Take with food"
            else     -> ""
        }
        if (foodText.isNotEmpty()) {
            findViewById<TextView>(R.id.food_text).text = foodText
        } else {
            findViewById<LinearLayout>(R.id.food_row).visibility = View.GONE
        }

        // Set time — format nicely
        if (time.isNotEmpty()) {
            val parts = time.split(":")
            if (parts.size == 2) {
                val hour = parts[0].toIntOrNull() ?: 0
                val minute = parts[1]
                val period = if (hour >= 12) "PM" else "AM"
                val displayHour = when {
                    hour > 12 -> hour - 12
                    hour == 0 -> 12
                    else -> hour
                }
                findViewById<TextView>(R.id.time_text).text = "$displayHour:$minute $period"
            } else {
                findViewById<TextView>(R.id.time_text).text = time
            }
        }

        // Start vibration
        startVibration()

        // Dismiss button
        findViewById<Button>(R.id.dismiss_button).setOnClickListener {
            stopVibration()
            finish()
        }

        // Take Now button — open main app
        findViewById<Button>(R.id.take_button).setOnClickListener {
            stopVibration()
            val mainIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            mainIntent?.let { startActivity(it) }
            finish()
        }
    }

    private fun startVibration() {
        val pattern = longArrayOf(0, 1000, 500, 1000, 500, 1000)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vibrator = vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    private fun stopVibration() {
        vibrator?.cancel()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopVibration()
    }
}
