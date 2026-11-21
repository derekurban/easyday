package app.easyday

import android.content.Context
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.PutDataRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONObject
import java.io.File

/// The phone end of the watch link (docs/app/WATCH.md). What the watch sends (taps, heart rate) comes in through
/// [WatchListenerService], which Android starts even when the app is not running, and waits here in a small file until
/// Dart reads it; Dart is told at once when it is listening. What the watch shows goes out as one data item.
object WatchInbox {
    const val STATE_PATH = "/easyday/state"
    private const val MAX = 400   // a long workout's heart batches, and some

    /// Set while the Flutter engine is up: tells Dart there is something to read.
    @Volatile var notify: (() -> Unit)? = null

    private fun file(context: Context) = File(context.noBackupFilesDir, "watch-inbox.jsonl")

    @Synchronized
    fun add(context: Context, path: String, data: String) {
        val f = file(context)
        val line = JSONObject().put("path", path).put("data", data).put("at", System.currentTimeMillis()).toString()
        val lines = (if (f.exists()) f.readLines() else emptyList()) + line
        f.writeText(lines.takeLast(MAX).joinToString("\n", postfix = "\n"))
    }

    /// Everything waiting, oldest first; the inbox is empty after.
    @Synchronized
    fun take(context: Context): List<Map<String, Any?>> {
        val f = file(context)
        if (!f.exists()) return emptyList()
        val out = f.readLines().filter { it.isNotBlank() }.mapNotNull { l ->
            try {
                val j = JSONObject(l)
                mapOf("path" to j.getString("path"), "data" to j.getString("data"), "at" to j.getLong("at"))
            } catch (e: Exception) { null }
        }
        f.delete()
        return out
    }

    /// Sends what the watch shows. Urgent, so a watch on the wrist hears it at once rather than in Android's own time.
    fun publish(context: Context, json: String, done: (Boolean) -> Unit) {
        try {
            val req = PutDataRequest.create(STATE_PATH).setData(json.toByteArray()).setUrgent()
            Wearable.getDataClient(context).putDataItem(req)
                .addOnSuccessListener { done(true) }
                .addOnFailureListener { done(false) }
        } catch (e: Exception) {
            done(false)  // no Google Play services, or no Wear API on this phone
        }
    }
}

/// Hears the watch. Android binds it for every message on our paths, whether or not the app is running.
class WatchListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (!event.path.startsWith("/easyday/")) return
        WatchInbox.add(applicationContext, event.path, String(event.data))
        WatchInbox.notify?.invoke()
    }
}
