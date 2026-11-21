package app.easyday.wear

import org.json.JSONArray
import org.json.JSONObject

/// What the phone says to show: its watch view (lib/logic/watch_view.dart), read into plain classes. Anything the
/// phone leaves out is null. docs/app/WATCH.md.
data class View(
    val version: Int,
    val phase: String,            // idle, today, lift, rest, timed, choose, review, done
    val step: String,             // the step this view is of: every tap names it
    val seq: Long,
    val sentAt: Long,             // the phone's real time when it sent this: a later one replaces an earlier
    val skew: Long,               // the phone's clock against real time (its prototype day shift)
    val hold: Boolean,            // the main button waits a moment after each step
    val session: String?,
    val title: String?,
    val kind: String?,            // lift, cardio, mobility
    val startedAt: Long?,
    val pausedAt: Long?,
    val record: Boolean,
    val steps: Steps?,
    val line: String?,
    val plan: Plan?,
    val ex: Ex?,
    val rest: Rest?,
    val timed: Timed?,
    val choices: List<Choice>,
    val moveOn: String?,
) {
    data class Steps(val done: Int, val total: Int, val at: Int, val between: Boolean)
    data class Plan(val name: String, val detail: String, val canStart: Boolean)
    data class Ex(val index: Int, val name: String, val level: String?, val set: Int, val sets: Int, val lo: Int, val hi: Int,
                  val unit: String, val values: List<Int>, val initial: Int, val test: Boolean, val side: Boolean)
    data class Rest(val last: String?, val next: String?, val button: String, val op: String)
    data class Timed(val kind: String, val name: String, val minutes: Int, val startedAt: Long?, val stopwatch: Boolean, val button: String, val op: String)
    data class Choice(val ex: Int, val name: String, val detail: String)

    val paused get() = pausedAt != null
    val inWorkout get() = phase in setOf("lift", "rest", "timed", "choose")

    /// The phone's clock now, from the watch's.
    fun phoneNow() = System.currentTimeMillis() + skew

    /// The workout's time so far, in seconds: stopped while paused.
    fun elapsed(): Long {
        val start = startedAt ?: return 0
        return ((pausedAt ?: phoneNow()) - start).coerceAtLeast(0) / 1000
    }

    companion object {
        const val VERSION = 1

        fun parse(json: String): View? = try { from(JSONObject(json)) } catch (e: Exception) { null }

        private fun JSONObject.str(k: String) = if (has(k) && !isNull(k)) getString(k) else null
        private fun JSONObject.long(k: String) = if (has(k) && !isNull(k)) getLong(k) else null
        private fun JSONObject.obj(k: String) = if (has(k) && !isNull(k)) getJSONObject(k) else null
        private fun JSONArray.ints() = List(length()) { getInt(it) }

        fun from(j: JSONObject) = View(
            version = j.optInt("v", 0),
            phase = j.optString("phase", "idle"),
            step = j.optString("step", ""),
            seq = j.optLong("seq", 0),
            sentAt = j.optLong("sentAt", 0),
            skew = j.optLong("skew", 0),
            hold = j.optBoolean("hold", true),
            session = j.str("session"),
            title = j.str("title"),
            kind = j.str("kind"),
            startedAt = j.long("startedAt"),
            pausedAt = j.long("pausedAt"),
            record = j.optBoolean("record", false),
            steps = j.obj("steps")?.let { Steps(it.optInt("done"), it.optInt("total"), it.optInt("at"), it.optBoolean("between")) },
            line = j.str("line"),
            plan = j.obj("plan")?.let { Plan(it.optString("name"), it.optString("detail"), it.optBoolean("canStart")) },
            ex = j.obj("ex")?.let {
                Ex(it.optInt("index"), it.optString("name"), it.str("level"), it.optInt("set"), it.optInt("sets"), it.optInt("lo"), it.optInt("hi"),
                    it.optString("unit", "reps"), it.optJSONArray("values")?.ints() ?: emptyList(), it.optInt("initial"), it.optBoolean("test"), it.optBoolean("side"))
            },
            rest = j.obj("rest")?.let { Rest(it.str("last"), it.str("next"), it.optString("button", "I'm ready"), it.optString("op", "ready")) },
            timed = j.obj("timed")?.let {
                Timed(it.optString("kind"), it.optString("name"), it.optInt("minutes"), it.long("startedAt"), it.optBoolean("stopwatch"), it.optString("button", "Done"), it.optString("op", "ready"))
            },
            choices = j.optJSONArray("choices")?.let { a -> List(a.length()) { a.getJSONObject(it).let { c -> Choice(c.optInt("ex"), c.optString("name"), c.optString("detail")) } } } ?: emptyList(),
            moveOn = j.str("moveOn"),
        )
    }
}
