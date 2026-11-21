package app.easyday.wear

import android.content.Context
import android.net.Uri
import android.util.Log
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONArray
import org.json.JSONObject

/// The watch end of the link (docs/app/WATCH.md). The phone keeps one data item, its watch view, and the watch shows
/// it; taps and heart rate go to the phone as messages. Every tap names the step it was made on, and waits for the
/// phone's answer: a new view. No answer within a few seconds and the phone is asleep (the app is closed there).
object Link {
    const val STATE_PATH = "/easyday/state"
    private const val CMD_PATH = "/easyday/cmd"
    private const val HEART_PATH = "/easyday/heart"
    private const val PHONE_CAPABILITY = "easyday_phone"
    private const val ANSWER_MS = 6000L

    enum class Phone { Unknown, Here, Asleep, Away }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val _view = MutableStateFlow<View?>(null)
    private val _phone = MutableStateFlow(Phone.Unknown)
    private val _waiting = MutableStateFlow(false)
    val view: StateFlow<View?> = _view
    val phone: StateFlow<Phone> = _phone
    /// A tap is on its way and the phone has not answered yet.
    val waiting: StateFlow<Boolean> = _waiting
    private var timeout: Job? = null

    /// A view from the phone: kept unless it is older than the one shown.
    fun accept(bytes: ByteArray) {
        val v = View.parse(String(bytes)) ?: return
        val now = _view.value
        if (now != null && v.sentAt < now.sentAt) return  // a slow one, overtaken
        _view.value = v
        _phone.value = Phone.Here
        _waiting.value = false
        timeout?.cancel()
    }

    /// The view the phone left last, from the data layer, for a watch app just opened.
    fun load(context: Context) = scope.launch {
        try {
            val items = Wearable.getDataClient(context).getDataItems(Uri.Builder().scheme("wear").path(STATE_PATH).build()).await()
            items.forEach { item -> item.data?.let { accept(it) } }  // one per phone; the newest stands
            items.release()
        } catch (e: Exception) {
            Log.w("Easyday", "load: $e")
        }
    }

    /// Asks the phone for its view now: the answer says whether the app there is awake.
    fun hello(context: Context) = send(context, "hello")

    /// A tap, for the step on screen.
    fun send(context: Context, op: String, extra: Map<String, Any> = emptyMap()) {
        val v = _view.value
        val cmd = JSONObject().put("op", op).put("at", v?.phoneNow() ?: System.currentTimeMillis())
        if (v != null) { cmd.put("step", v.step); v.session?.let { cmd.put("session", it) } }
        extra.forEach { (k, x) -> cmd.put(k, x) }
        _waiting.value = true
        timeout?.cancel()
        timeout = scope.launch {
            delay(ANSWER_MS)
            _waiting.value = false
            if (_phone.value != Phone.Away) _phone.value = Phone.Asleep
        }
        scope.launch {
            val ok = message(context, CMD_PATH, cmd.toString())
            if (!ok) { timeout?.cancel(); _waiting.value = false; _phone.value = Phone.Away }
        }
    }

    /// Heart rate for the phone: (ms, bpm) samples of [session], the energy so far, the watch's name. False when no phone
    /// heard it, so the samples are kept and sent again.
    suspend fun sendHeart(context: Context, session: String, samples: List<Pair<Long, Int>>, kcal: Double?, device: String): Boolean {
        val j = JSONObject().put("session", session).put("device", device)
            .put("samples", JSONArray().apply { samples.forEach { (t, b) -> put(JSONArray().put(t).put(b)) } })
        if (kcal != null) j.put("kcal", kcal)
        return message(context, HEART_PATH, j.toString())
    }

    private suspend fun message(context: Context, path: String, body: String): Boolean {
        val node = phoneNode(context) ?: return false
        return try {
            Wearable.getMessageClient(context).sendMessage(node.id, path, body.toByteArray()).await()
            true
        } catch (e: Exception) {
            Log.w("Easyday", "send $path: $e")
            false
        }
    }

    /// The phone with Easyday on it, the nearest first; any connected phone when none says so yet.
    private suspend fun phoneNode(context: Context): Node? = try {
        val caps = Wearable.getCapabilityClient(context).getCapability(PHONE_CAPABILITY, CapabilityClient.FILTER_REACHABLE).await()
        caps.nodes.firstOrNull { it.isNearby } ?: caps.nodes.firstOrNull()
            ?: Wearable.getNodeClient(context).connectedNodes.await().firstOrNull()
    } catch (e: Exception) {
        null
    }

    /// For the screenshots: a view as if the phone had sent it.
    fun show(v: View) { _view.value = v; _phone.value = Phone.Here }
    fun pretendAsleep() { _phone.value = Phone.Asleep }
}
