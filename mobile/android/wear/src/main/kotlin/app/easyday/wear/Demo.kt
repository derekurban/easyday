package app.easyday.wear

import org.json.JSONArray
import org.json.JSONObject

/// Made-up views, as the phone would send them, for looking at every screen without a phone (debug builds only):
/// `adb shell am start -n app.easyday.staging.dev/app.easyday.wear.MainActivity --es demo lift`.
object Demo {
    var on = false
        private set
    /// The "live" demo: a lift that records, so the heart rate comes from Health Services (the emulator's made-up one).
    var live = false
        private set

    fun show(name: String) {
        on = true
        live = name == "live"
        val now = System.currentTimeMillis()
        val base = JSONObject().put("v", 1).put("seq", 1).put("sentAt", now).put("skew", 0).put("hold", false)
            .put("session", "s1").put("title", "Lats and biceps day").put("kind", "lift")
            .put("startedAt", now - 754_000).put("record", name == "live")
            .put("steps", JSONObject().put("done", 5).put("total", 14).put("at", 5).put("between", name == "rest"))
        val j = when (name) {
            "today" -> JSONObject().put("v", 1).put("sentAt", now).put("phase", "today").put("step", "today")
                .put("plan", JSONObject().put("name", "Lats and biceps day").put("detail", "5 exercises · about 40 min").put("canStart", true))
            "idle" -> JSONObject().put("v", 1).put("sentAt", now).put("phase", "idle").put("step", "idle").put("line", "Done for today")
            "rest" -> base.put("phase", "rest").put("step", "rest")
                .put("rest", JSONObject().put("last", "10 reps").put("next", "Lat pulldown").put("button", "Start set 3").put("op", "ready"))
            "timed" -> base.put("phase", "timed").put("step", "cardio")
                .put("timed", JSONObject().put("kind", "cardio").put("name", "Cardio").put("minutes", 10).put("startedAt", now - 312_000)
                    .put("stopwatch", true).put("button", "Start stretching").put("op", "cardio"))
            "choose" -> base.put("phase", "choose").put("step", "choose").put("moveOn", "Start cardio")
                .put("choices", JSONArray()
                    .put(JSONObject().put("ex", 1).put("name", "Lat pulldown").put("detail", "Set 2 of 3 · 45 kg"))
                    .put(JSONObject().put("ex", 2).put("name", "Hammer curl").put("detail", "Set 1 of 3 · 12 kg per hand"))
                    .put(JSONObject().put("ex", 3).put("name", "Face pull").put("detail", "Set 1 of 2 · 20 kg")))
            "paused" -> base.put("phase", "lift").put("step", "lift").put("pausedAt", now - 30_000).put("ex", ex())
            "review" -> base.put("phase", "review").put("step", "review").put("line", "Wrap up on your phone")
            "asleep" -> base.put("phase", "lift").put("step", "lift").put("ex", ex())
            else -> base.put("phase", "lift").put("step", "lift").put("ex", ex())
        }
        Link.show(View.from(j))
        if (name == "asleep") Link.pretendAsleep()
        if (live) return
        Heart.bpm.value = if (name == "rest") 131 else 118
        Heart.state.value = Heart.State.On
        Heart.session = "s1"
        Heart.kcal.value = 214.0
        Heart.stats.value = Heart.Stats(count = 120, sum = 120L * 112, peak = 156)
    }

    private fun ex() = JSONObject().put("index", 1).put("name", "Barbell bent-over row").put("level", "50 kg").put("set", 2).put("sets", 3)
        .put("lo", 8).put("hi", 12).put("unit", "reps").put("values", JSONArray((0..18).toList())).put("initial", 12).put("test", false).put("side", false)
}
