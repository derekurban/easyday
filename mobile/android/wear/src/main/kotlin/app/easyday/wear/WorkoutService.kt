package app.easyday.wear

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.ExerciseConfig
import androidx.health.services.client.data.ExerciseLapSummary
import androidx.health.services.client.data.ExerciseTrackedStatus
import androidx.health.services.client.data.ExerciseType
import androidx.health.services.client.data.ExerciseUpdate
import androidx.wear.ongoing.OngoingActivity
import androidx.wear.ongoing.Status
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.time.Instant
import kotlin.math.roundToInt

/// What the watch has read of the heart during the workout under way: shown on the watch, and sent to the phone.
object Heart {
    enum class State { Off, Starting, On, Unavailable }
    val state = MutableStateFlow(State.Off)
    val bpm = MutableStateFlow<Int?>(null)
    val kcal = MutableStateFlow<Double?>(null)
    /// This workout's readings so far, for the watch's own summary when it ends.
    val stats = MutableStateFlow(Stats())
    var session: String? = null

    data class Stats(val count: Int = 0, val sum: Long = 0, val peak: Int = 0) {
        val avg get() = if (count == 0) null else (sum / count).toInt()
        fun with(b: Int) = Stats(count + 1, sum + b, maxOf(peak, b))
    }
}

/// Records the heart rate while a workout is under way on the phone: a foreground service holding a Health Services
/// exercise, so the readings keep coming with the screen off. It follows the phone's view: it starts with a workout,
/// pauses and resumes with it, and ends when the phone's workout ends (or another starts). Readings go to the phone in
/// batches every [SEND_EVERY_MS], and again until the phone has them. docs/app/WATCH.md.
class WorkoutService : Service() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val client by lazy { HealthServices.getClient(this).exerciseClient }
    private var session: String? = null
    private var exercising = false
    private var paused = false
    private var ending = false
    private val unsent = mutableListOf<Pair<Long, Int>>()
    private var follow: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val v = Link.view.value
        val id = intent?.getStringExtra(EXTRA_SESSION) ?: v?.session
        // one workout per run: a new one waits until this one has ended and sent its last readings
        if (id == null || session != null || ending) return START_NOT_STICKY
        session = id
        Heart.session = id
        Heart.stats.value = Heart.Stats()
        Heart.bpm.value = null
        Heart.kcal.value = null
        running.value = id
        goForeground(v?.title ?: "Workout")
        scope.launch { startExercise(v?.kind ?: "lift") }
        follow?.cancel()
        follow = scope.launch { Link.view.collect { follow(it) } }
        scope.launch { while (isActive) { delay(SEND_EVERY_MS); flush() } }
        // a workout left running on the phone ends here after this long, so a lost phone does not drain the battery
        scope.launch { delay(MAX_MS); end() }
        return START_NOT_STICKY
    }

    private fun goForeground(title: String) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "Workout", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), PendingIntent.FLAG_IMMUTABLE)
        val nb = NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_heart)
            .setContentTitle(title)
            .setContentText("Workout under way")
            .setCategory(NotificationCompat.CATEGORY_WORKOUT)
            .setOngoing(true)
            .setContentIntent(open)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
        // the watch face shows it, and a tap there comes back here
        OngoingActivity.Builder(applicationContext, NOTIFICATION, nb)
            .setStaticIcon(R.drawable.ic_heart)
            .setTouchIntent(open)
            .setStatus(Status.Builder().addTemplate(title).build())
            .build()
            .apply(applicationContext)
        val type = if (Build.VERSION.SDK_INT >= 34) ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH else 0
        try {
            ServiceCompat.startForeground(this, NOTIFICATION, nb.build(), type)
        } catch (e: Exception) {
            Log.w("Easyday", "foreground: $e")  // no sensor permission yet: nothing to record
            Heart.state.value = Heart.State.Unavailable
            stopSelf()
        }
    }

    private suspend fun startExercise(kind: String) {
        if (!canRead(this)) { Heart.state.value = Heart.State.Unavailable; return }
        Heart.state.value = Heart.State.Starting
        try {
            val info = client.getCurrentExerciseInfoAsync().await()
            if (info.exerciseTrackedStatus == ExerciseTrackedStatus.OWNED_EXERCISE_IN_PROGRESS) client.endExerciseAsync().await()
            val caps = client.getCapabilitiesAsync().await()
            val wanted = when (kind) {
                "lift" -> listOf(ExerciseType.STRENGTH_TRAINING, ExerciseType.WEIGHTLIFTING, ExerciseType.WORKOUT)
                "mobility" -> listOf(ExerciseType.STRETCHING, ExerciseType.YOGA, ExerciseType.WORKOUT)
                else -> listOf(ExerciseType.WORKOUT)
            }
            val type = wanted.firstOrNull { it in caps.supportedExerciseTypes } ?: run { Heart.state.value = Heart.State.Unavailable; return }
            val supported = caps.getExerciseTypeCapabilities(type).supportedDataTypes
            val types = setOf<DataType<*, *>>(DataType.HEART_RATE_BPM, DataType.CALORIES_TOTAL).filter { it in supported }.toSet()
            if (DataType.HEART_RATE_BPM !in types) { Heart.state.value = Heart.State.Unavailable; return }
            client.setUpdateCallback(callback)
            client.startExerciseAsync(ExerciseConfig.builder(type).setDataTypes(types).setIsAutoPauseAndResumeEnabled(false).setIsGpsEnabled(false).build()).await()
            exercising = true
            Heart.state.value = Heart.State.On
            if (Link.view.value?.paused == true) pause(true)
        } catch (e: Exception) {
            Log.w("Easyday", "exercise: $e")  // another app holds an exercise, or no sensor here
            Heart.state.value = Heart.State.Unavailable
        }
    }

    private val callback = object : ExerciseUpdateCallback {
        override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
            val boot = Instant.ofEpochMilli(System.currentTimeMillis() - SystemClock.elapsedRealtime())
            val m = update.latestMetrics
            for (p in m.getData(DataType.HEART_RATE_BPM)) {
                val b = p.value.roundToInt()
                if (b < 30 || b > 230) continue
                unsent.add(p.getTimeInstant(boot).toEpochMilli() to b)
                Heart.bpm.value = b
                Heart.stats.value = Heart.stats.value.with(b)
            }
            m.getData(DataType.CALORIES_TOTAL)?.let { Heart.kcal.value = it.total }
            if (unsent.size > MAX_UNSENT) unsent.subList(0, unsent.size - MAX_UNSENT).clear()
        }
        override fun onLapSummaryReceived(lapSummary: ExerciseLapSummary) {}
        override fun onRegistered() {}
        override fun onRegistrationFailed(throwable: Throwable) { Log.w("Easyday", "callback: $throwable") }
        override fun onAvailabilityChanged(dataType: DataType<*, *>, availability: Availability) {}
    }

    /// The phone's view changed: pause, resume, or end with it.
    private suspend fun follow(v: View?) {
        if (ending) return
        if (v == null || !v.record || v.session != session) { end(); return }
        if (v.paused != paused) pause(v.paused)
    }

    private suspend fun pause(on: Boolean) {
        paused = on
        if (!exercising) return
        try {
            if (on) client.pauseExerciseAsync().await() else client.resumeExerciseAsync().await()
        } catch (e: Exception) { Log.w("Easyday", "pause: $e") }
    }

    private suspend fun flush(): Boolean {
        val id = session ?: return true
        if (unsent.isEmpty() && Heart.kcal.value == null) return true
        val batch = unsent.toList()
        val ok = Link.sendHeart(this, id, batch, Heart.kcal.value, deviceName(this))
        if (ok) unsent.subList(0, batch.size.coerceAtMost(unsent.size)).clear()
        return ok
    }

    private suspend fun end() {
        if (ending) return
        ending = true
        follow?.cancel()
        if (exercising) {
            try { client.endExerciseAsync().await() } catch (e: Exception) { Log.w("Easyday", "end: $e") }
            try { client.clearUpdateCallbackAsync(callback).await() } catch (_: Exception) {}
        }
        exercising = false
        // what is left goes to the phone; a phone out of reach gets a few more tries
        for (i in 0 until 4) { if (flush()) break; delay(5000) }
        Heart.state.value = Heart.State.Off
        running.value = null
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        running.value = null
        scope.cancel()
        super.onDestroy()
    }

    companion object {
        const val EXTRA_SESSION = "session"
        private const val CHANNEL = "workout"
        private const val NOTIFICATION = 7
        private const val SEND_EVERY_MS = 15_000L
        private const val MAX_MS = 4 * 60 * 60 * 1000L
        private const val MAX_UNSENT = 4000

        private val running = MutableStateFlow<String?>(null)
        /// The session being recorded, if any.
        val recording: StateFlow<String?> = running

        /// Starts recording [session], from a screen the user can see (Android lets a foreground service start only so).
        fun start(context: Context, session: String) {
            if (running.value == session) return
            ContextCompat.startForegroundService(context, Intent(context, WorkoutService::class.java).putExtra(EXTRA_SESSION, session))
        }

        /// The permissions the heart rate needs on this watch.
        fun permissions(): Array<String> = buildList {
            add(if (Build.VERSION.SDK_INT >= 36) "android.permission.health.READ_HEART_RATE" else Manifest.permission.BODY_SENSORS)
            add(Manifest.permission.ACTIVITY_RECOGNITION)
            if (Build.VERSION.SDK_INT >= 33) add(Manifest.permission.POST_NOTIFICATIONS)
        }.toTypedArray()

        fun canRead(context: Context) = ContextCompat.checkSelfPermission(context, permissions()[0]) == PackageManager.PERMISSION_GRANTED

        /// The watch's own name, as its owner set it ('Galaxy Watch4 (1A2B)'), else its model.
        fun deviceName(context: Context): String =
            Settings.Global.getString(context.contentResolver, "device_name")?.takeIf { it.isNotBlank() } ?: Build.MODEL
    }
}
