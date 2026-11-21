package app.easyday.wear

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.WearableListenerService

/// Hears the phone's view, whether or not the watch app is open. A workout started on the phone while the app is
/// closed here gets one notification: a tap opens the app, which starts recording (Android lets a foreground service
/// start only from something the user sees).
class PhoneListener : WearableListenerService() {
    override fun onDataChanged(events: DataEventBuffer) {
        for (e in events) {
            if (e.type != DataEvent.TYPE_CHANGED || e.dataItem.uri.path != Link.STATE_PATH) continue
            e.dataItem.data?.let { Link.accept(it) }
        }
        val v = Link.view.value ?: return
        val id = v.session ?: return
        if (!v.record || MainActivity.visible || WorkoutService.recording.value == id) return
        val prefs = getSharedPreferences("easyday", MODE_PRIVATE)
        if (prefs.getString("told", null) == id) return
        prefs.edit().putString("told", id).apply()
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "Workout started", NotificationManager.IMPORTANCE_HIGH))
        val open = PendingIntent.getActivity(this, 1, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK), PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_heart)
            .setContentTitle(v.title ?: "Workout")
            .setContentText("Tap to follow it on your watch")
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        try { nm.notify(NOTIFICATION, n) } catch (_: SecurityException) {}  // notifications not allowed
    }

    companion object {
        private const val CHANNEL = "started"
        const val NOTIFICATION = 8
    }
}
