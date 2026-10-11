package com.roadassist.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelId = "roadassist_alerts_v1"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val alerts = NotificationChannel(channelId, "RoadAssist alerts", NotificationManager.IMPORTANCE_HIGH)
            alerts.description = "Requests, service progress and messages"
            alerts.enableVibration(true)
            alerts.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
            manager.createNotificationChannel(alerts)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "roadassist/alerts")
            .setMethodCallHandler { call, result ->
                if (call.method != "play") { result.notImplemented(); return@setMethodCallHandler }
                val audio = getSystemService(AUDIO_SERVICE) as AudioManager
                val permitted = audio.ringerMode == AudioManager.RINGER_MODE_NORMAL &&
                    manager.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL &&
                    (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || manager.areNotificationsEnabled())
                val channel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) manager.getNotificationChannel(channelId) else null
                val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) channel?.sound
                    else RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                if (permitted && uri != null && (channel == null || channel.importance != NotificationManager.IMPORTANCE_NONE)) {
                    val tone = RingtoneManager.getRingtone(this, uri)
                    tone?.audioAttributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build()
                    tone?.play()
                    Handler(Looper.getMainLooper()).postDelayed({ tone?.stop() }, 4000)
                }
                result.success(null)
            }
    }
}
