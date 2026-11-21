package app.easyday.wear

import android.view.HapticFeedbackConstants
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.basicMarquee
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.gestures.detectVerticalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.CurvedLayout
import androidx.wear.compose.foundation.CurvedTextStyle
import androidx.wear.compose.material3.curvedText
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.EdgeButton
import androidx.wear.compose.material3.EdgeButtonSize
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.Text
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

typealias Send = (op: String, extra: Map<String, Any>) -> Unit

/// Whatever the phone's view says. One thing at a time, as on the phone: the set under way and its reps, the rest and
/// the button to the next, a timed part, the free-form list. Swipe left for pause and end. docs/app/WATCH.md.
@Composable
fun App(send: Send) {
    val v by Link.view.collectAsState()
    val phone by Link.phone.collectAsState()
    val view = v
    Box(Modifier.fillMaxSize().background(Ink.bg)) {
        when {
            view == null -> Message(R.drawable.ic_phone, if (phone == Link.Phone.Unknown) "Looking for your phone" else "Open Easyday on your phone")
            view.version > View.VERSION -> Message(R.drawable.ic_phone, "Update Easyday on your watch")
            view.phase == "today" -> Today(view, send)
            view.phase == "review" || view.phase == "done" -> Ended(view)
            view.inWorkout -> Workout(view, send)
            else -> Message(null, view.line ?: "Open Easyday to plan today", clock = true)
        }
    }
}

// ---- the parts every screen shares ----

/// The top of the screen, along the edge: the workout's clock (the only clock in a workout), or the time of day.
@Composable
private fun TopText(text: String) {
    CurvedLayout(Modifier.fillMaxSize().padding(6.dp), anchor = 270f) {
        curvedText(text, style = CurvedTextStyle(fontSize = 14.sp, color = Ink.ink2, fontFamily = Fonts.wix))
    }
}

@Composable
private fun now(): Long {
    val t by produceState(System.currentTimeMillis()) {
        while (true) { delay(1000 - System.currentTimeMillis() % 1000); value = System.currentTimeMillis() }
    }
    return t
}

private fun clock(seconds: Long): String {
    val h = seconds / 3600; val m = seconds / 60 % 60; val s = seconds % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}

/// The strip, round the edge: a mark for every set and timed part, done ones in ink, the one under way in the sun.
@Composable
private fun StepsRing(steps: View.Steps?) {
    if (steps == null || steps.total <= 0) return
    Canvas(Modifier.fillMaxSize().padding(3.dp)) {
        val stroke = 3.dp.toPx()
        val inset = stroke / 2
        val box = Size(size.width - stroke, size.height - stroke)
        val start = 140f; val sweep = 260f  // open at the bottom, where the button is
        val n = steps.total
        val gap = if (n > 40) 0f else 2.2f
        val each = (sweep - gap * (n - 1)) / n
        for (i in 0 until n) {
            val c = when {
                i < steps.done -> Ink.ink2
                i == steps.at && !steps.between -> Ink.sun
                else -> Ink.ahead
            }
            drawArc(c, start + i * (each + gap), each, false, topLeft = Offset(inset, inset), size = box, style = Stroke(stroke, cap = StrokeCap.Butt))
        }
    }
}

/// The one button, along the bottom edge. After each step it waits a moment (the phone's setting) before it can be
/// pressed, saying what to do meanwhile, so a quick second tap cannot skip what comes next.
@Composable
private fun BoxScope.MainButton(label: String, key: String, hold: Boolean, caption: String, enabled: Boolean = true, onClick: () -> Unit) {
    val waiting by Link.waiting.collectAsState()
    var ready by remember(key) { mutableStateOf(!hold) }
    LaunchedEffect(key) { if (hold) { delay(HOLD_MS); ready = true } }
    val view = LocalView.current
    val on = ready && enabled && !waiting
    EdgeButton(
        onClick = { if (on) { view.performHapticFeedback(HapticFeedbackConstants.CONFIRM); onClick() } },
        modifier = Modifier.align(Alignment.BottomCenter),
        buttonSize = EdgeButtonSize.Small,
        enabled = on,
        colors = ButtonDefaults.buttonColors(containerColor = Ink.sun, contentColor = Ink.onSun, disabledContainerColor = Ink.sunk, disabledContentColor = Ink.ink3),
    ) {
        Text(if (ready) label else caption, style = if ((if (ready) label else caption).length > 13) Type.buttonLong else Type.button, maxLines = 2, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center)
    }
}

private const val HOLD_MS = 2000L

@Composable
private fun HeartRate(big: Boolean = false) {
    val bpm by Heart.bpm.collectAsState()
    val state by Heart.state.collectAsState()
    if (state == Heart.State.Off || state == Heart.State.Unavailable) return
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.semantics { contentDescription = "Heart rate ${bpm ?: "reading"}" }) {
        Icon(painterResource(R.drawable.ic_heart_filled), contentDescription = null, tint = Ink.art, modifier = Modifier.size(if (big) 18.dp else 13.dp))
        Spacer(Modifier.width(if (big) 6.dp else 4.dp))
        Text(bpm?.toString() ?: "–", style = if (big) Type.number else Type.small, color = if (big) Ink.ink else Ink.ink2)
        if (big) Text(" bpm", style = Type.small, color = Ink.ink2)
    }
}

/// When a tap got no answer: the app on the phone is closed. Shown in place of the line under the title.
@Composable
private fun phoneLine(): String? {
    val phone by Link.phone.collectAsState()
    return when (phone) {
        Link.Phone.Asleep -> "Open Easyday on phone"
        Link.Phone.Away -> "Phone out of reach"
        else -> null
    }
}

@Composable
private fun Message(icon: Int?, text: String, clock: Boolean = false) {
    if (clock) TopText(SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(now())))
    Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        if (icon != null) {
            Icon(painterResource(icon), contentDescription = null, tint = Ink.ink2, modifier = Modifier.size(28.dp))
            Spacer(Modifier.height(10.dp))
        }
        Text(text, style = Type.body, color = Ink.ink, textAlign = TextAlign.Center)
        Spacer(Modifier.height(6.dp))
        Text("Easyday", style = Type.small, color = Ink.ink3)
    }
}

// ---- Today ----

@Composable
private fun Today(v: View, send: Send) {
    val p = v.plan ?: return
    Box(Modifier.fillMaxSize()) {
        TopText(SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(now())))
        Column(Modifier.fillMaxSize().padding(start = 22.dp, end = 22.dp, top = 28.dp, bottom = 46.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Text("Today", style = Type.small, color = Ink.ink2)
            Spacer(Modifier.height(2.dp))
            Text(p.name, style = Type.title, color = Ink.ink, textAlign = TextAlign.Center, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(4.dp))
            Text(phoneLine() ?: p.detail, style = Type.small, color = if (phoneLine() != null) Ink.warning else Ink.ink2, textAlign = TextAlign.Center)
        }
        if (p.canStart) MainButton("Start", v.step, hold = false, caption = "") { send("start", emptyMap()) }
        else Text("Start it on your phone", style = Type.small, color = Ink.ink3, modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 22.dp))
    }
}

// ---- a workout under way ----

@Composable
private fun Workout(v: View, send: Send) {
    val pager = rememberPagerState { 2 }
    HorizontalPager(pager, Modifier.fillMaxSize()) { page ->
        if (page == 0) Step(v, send) else Controls(v, send)
    }
    // two dots, on the side the other page is: the bottom is the button's (not over the free-form list's rows)
    if (v.phase != "choose" || pager.currentPage == 1) Column(Modifier.fillMaxSize().padding(horizontal = 10.dp), verticalArrangement = Arrangement.Center,
        horizontalAlignment = if (pager.currentPage == 0) Alignment.End else Alignment.Start) {
        for (i in 0..1) Box(Modifier.padding(vertical = 2.dp).size(4.dp).clip(CircleShape).background(if (pager.currentPage == i) Ink.ink2 else Ink.ahead))
    }
}

@Composable
private fun Step(v: View, send: Send) {
    val t = now()
    Box(Modifier.fillMaxSize()) {
        if (v.phase != "choose") StepsRing(v.steps)  // the list runs to the edge
        val elapsed = clock(v.elapsed())
        TopText(if (v.paused) "$elapsed paused" else elapsed)
        Box(Modifier.fillMaxSize().alpha(if (v.paused) 0.45f else 1f)) {
            when (v.phase) {
                "lift" -> Lift(v, send)
                "rest" -> Rest(v)
                "timed" -> Timed(v, t)
                "choose" -> Choose(v, send)
            }
        }
        if (v.paused) MainButton("Resume", "${v.step} paused", hold = false, caption = "") { send("resume", emptyMap()) }
        else when (v.phase) {
            "rest" -> v.rest?.let { r -> MainButton(r.button, v.step, v.hold, "Catch your breath") { send(r.op, emptyMap()) } }
            "timed" -> v.timed?.let { m -> MainButton(m.button, v.step, v.hold, "Settle in") { send(m.op, emptyMap()) } }
            else -> {}
        }
    }
}

@Composable
private fun BoxScope.Lift(v: View, send: Send) {
    val e = v.ex ?: return
    var index by remember(v.step) { mutableIntStateOf(e.initial.coerceIn(0, (e.values.size - 1).coerceAtLeast(0))) }
    Column(Modifier.fillMaxSize().padding(start = 24.dp, end = 24.dp, top = 24.dp, bottom = 44.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(e.name, style = Type.liftTitle, color = Ink.ink, maxLines = 2, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center)
        // what this set is, its weight or version, and the reps to aim for
        val aim = if (e.lo == e.hi) "${e.hi}" else "${e.lo}–${e.hi}"
        val sub = if (e.test) listOfNotNull("As many as you can", e.level).joinToString(" · ")
            else listOfNotNull("Set ${e.set} of ${e.sets}", e.level, aim).joinToString(" · ")
        val warn = phoneLine()
        Text(warn ?: sub, style = Type.small, color = if (warn != null) Ink.warning else Ink.ink2, maxLines = if (warn != null) 2 else 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center)
        if (e.values.isNotEmpty()) RepDial(e.values, index, enabled = !v.paused) { index = it }
    }
    val unit = if (e.unit == "seconds") "s" else "reps"
    if (!v.paused) MainButton("Log ${e.values.getOrNull(index) ?: ""} $unit${if (e.side) " a side" else ""}", v.step, v.hold, "Settle in") {
        send("log", mapOf("reps" to (e.values.getOrNull(index) ?: 0)))
    }
}

/// The reps, on a dial: turn the bezel (or drag up and down, or tap a number either side) to the number. Sideways, so it
/// fits under a two-line name on a small round screen.
@Composable
private fun RepDial(values: List<Int>, index: Int, enabled: Boolean, onIndex: (Int) -> Unit) {
    val focus = remember { FocusRequester() }
    val view = LocalView.current
    var acc by remember { mutableFloatStateOf(0f) }
    fun move(by: Int) {
        val to = (index + by).coerceIn(0, values.size - 1)
        if (to != index) { view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK); onIndex(to) }
    }
    LaunchedEffect(Unit) { focus.requestFocus() }
    Row(
        Modifier
            .fillMaxWidth()
            .onRotaryScrollEvent { ev ->
                if (enabled) {
                    acc += ev.verticalScrollPixels
                    while (acc > ROTARY_STEP) { move(1); acc -= ROTARY_STEP }
                    while (acc < -ROTARY_STEP) { move(-1); acc += ROTARY_STEP }
                }
                true
            }
            .focusRequester(focus)
            .focusable()
            .pointerInput(index, enabled) {
                var drag = 0f
                detectVerticalDragGestures(onDragEnd = { drag = 0f }) { change, dy ->
                    change.consume()
                    if (!enabled) return@detectVerticalDragGestures
                    drag -= dy
                    if (drag > DRAG_STEP) { move(1); drag = 0f }
                    if (drag < -DRAG_STEP) { move(-1); drag = 0f }
                }
            }
            .semantics { contentDescription = "${values[index]}, turn the bezel to change" },
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val side = Modifier.width(40.dp)
        Text(values.getOrNull(index - 1)?.toString() ?: "", style = Type.dialSide, color = Ink.ink3,
            modifier = side.clickable(enabled = enabled && index > 0) { move(-1) })
        Text(values[index].toString(), style = Type.dial, color = Ink.ink, modifier = Modifier.width(64.dp))
        Text(values.getOrNull(index + 1)?.toString() ?: "", style = Type.dialSide, color = Ink.ink3,
            modifier = side.clickable(enabled = enabled && index < values.size - 1) { move(1) })
    }
}

private const val ROTARY_STEP = 48f
private const val DRAG_STEP = 34f

@Composable
private fun Rest(v: View) {
    val r = v.rest ?: return
    Column(Modifier.fillMaxSize().padding(start = 22.dp, end = 22.dp, top = 26.dp, bottom = 46.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Text("Rest", style = Type.small, color = Ink.ink2)
        Spacer(Modifier.height(4.dp))
        HeartRate(big = true)
        Spacer(Modifier.height(6.dp))
        val warn = phoneLine()
        if (warn != null) Text(warn, style = Type.small, color = Ink.warning, textAlign = TextAlign.Center, maxLines = 2)
        else {
            r.last?.let { Text("Logged $it", style = Type.small, color = Ink.ink2) }
            r.next?.let { Text("Next: $it", style = Type.small, color = Ink.ink2, maxLines = 1, overflow = TextOverflow.Ellipsis) }
        }
    }
}

@Composable
private fun Timed(v: View, now: Long) {
    val m = v.timed ?: return
    Column(Modifier.fillMaxSize().padding(start = 22.dp, end = 22.dp, top = 26.dp, bottom = 46.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
        Text(m.name, style = Type.title, color = Ink.ink, maxLines = 1, modifier = Modifier.basicMarquee())
        Spacer(Modifier.height(2.dp))
        if (m.stopwatch && m.startedAt != null) {
            // cardio's stopwatch: the one clock that is the work itself
            val secs = (((v.pausedAt ?: (now + v.skew)) - m.startedAt) / 1000).coerceAtLeast(0)
            Text(clock(secs), style = Type.dial, color = Ink.ink)
        } else if (m.minutes > 0) {
            Text("About ${m.minutes} min", style = Type.body, color = Ink.ink2)
        }
        Spacer(Modifier.height(4.dp))
        val warn = phoneLine()
        if (warn != null) Text(warn, style = Type.small, color = Ink.warning) else HeartRate()
    }
}

@Composable
private fun Choose(v: View, send: Send) {
    val list = rememberScalingLazyListState()
    ScalingLazyColumn(Modifier.fillMaxSize(), state = list, horizontalAlignment = Alignment.CenterHorizontally) {
        item { Text(phoneLine() ?: "Next exercise", style = Type.small, color = if (phoneLine() != null) Ink.warning else Ink.ink2, modifier = Modifier.padding(top = 18.dp, bottom = 4.dp)) }
        for (c in v.choices) item {
            Button(
                onClick = { send("pick", mapOf("ex" to c.ex)) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !v.paused,
                colors = ButtonDefaults.buttonColors(containerColor = Ink.sunk, contentColor = Ink.ink, secondaryContentColor = Ink.ink2),
                secondaryLabel = { Text(c.detail, style = Type.small, maxLines = 1, overflow = TextOverflow.Ellipsis) },
            ) { Text(c.name, style = Type.label, maxLines = 1, overflow = TextOverflow.Ellipsis) }
        }
        v.moveOn?.let { m -> item {
            Button(
                onClick = { send("moveOn", emptyMap()) },
                modifier = Modifier.fillMaxWidth(),
                enabled = !v.paused,
                colors = ButtonDefaults.buttonColors(containerColor = Ink.bg, contentColor = Ink.ink2),
            ) { Text(m, style = Type.label, maxLines = 1, overflow = TextOverflow.Ellipsis) }
        } }
    }
}

/// Swiped to the side: pause or resume, and end. A movement day has no end here: it ends with Done.
@Composable
private fun Controls(v: View, send: Send) {
    var confirm by remember(v.session) { mutableStateOf(false) }
    Box(Modifier.fillMaxSize()) {
        TopText(clock(v.elapsed()))
        if (confirm) {
            Column(Modifier.fillMaxSize().padding(22.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                Text("End the workout?", style = Type.title, color = Ink.ink, textAlign = TextAlign.Center)
                Spacer(Modifier.height(4.dp))
                Text("What you did counts. Wrap up on your phone.", style = Type.small, color = Ink.ink2, textAlign = TextAlign.Center)
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    RoundButton(R.drawable.ic_x, "No", Ink.sunk, Ink.ink) { confirm = false }
                    RoundButton(R.drawable.ic_check, "End", Ink.sun, Ink.onSun) { confirm = false; send("end", emptyMap()) }
                }
            }
        } else {
            Column(Modifier.fillMaxSize().padding(22.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                Text(v.title ?: "Workout", style = Type.label, color = Ink.ink2, maxLines = 1, modifier = Modifier.basicMarquee())
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    if (v.paused) RoundButton(R.drawable.ic_play, "Resume", Ink.sunk, Ink.ink) { send("resume", emptyMap()) }
                    else RoundButton(R.drawable.ic_pause, "Pause", Ink.sunk, Ink.ink) { send("pause", emptyMap()) }
                    if (v.kind == "lift") RoundButton(R.drawable.ic_flag, "End", Ink.sunk, Ink.ink) { confirm = true }
                }
                Spacer(Modifier.height(10.dp))
                HeartRate()
            }
        }
    }
}

@Composable
private fun RoundButton(icon: Int, label: String, fill: Color, ink: Color, onClick: () -> Unit) {
    val view = LocalView.current
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            Modifier.size(52.dp).clip(CircleShape).background(fill)
                .clickable { view.performHapticFeedback(HapticFeedbackConstants.CONFIRM); onClick() }
                .semantics { contentDescription = label },
            contentAlignment = Alignment.Center,
        ) { Icon(painterResource(icon), contentDescription = null, tint = ink, modifier = Modifier.size(22.dp)) }
        Spacer(Modifier.height(4.dp))
        Text(label, style = Type.small, color = Ink.ink2)
    }
}

// ---- the end ----

@Composable
private fun Ended(v: View) {
    val stats by Heart.stats.collectAsState()
    val kcal by Heart.kcal.collectAsState()
    val mine = Heart.session == v.session && stats.count > 0
    Box(Modifier.fillMaxSize()) {
        TopText(clock(v.elapsed()))
        Column(Modifier.fillMaxSize().padding(22.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(36.dp).clip(CircleShape).background(Ink.sunk), contentAlignment = Alignment.Center) {
                Icon(painterResource(R.drawable.ic_check), contentDescription = null, tint = Ink.ink, modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.height(8.dp))
            Text(if (v.phase == "done") "Logged" else "Workout ended", style = Type.title, color = Ink.ink)
            if (mine) {
                Spacer(Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    Stat("${stats.avg}", "avg bpm")
                    Stat("${stats.peak}", "peak")
                    kcal?.takeIf { it >= 1 }?.let { Stat("${it.toInt()}", "kcal") }
                }
            }
            Spacer(Modifier.height(6.dp))
            Text(v.line ?: "Wrap up on your phone", style = Type.small, color = Ink.ink2, textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun Stat(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = Type.number, color = Ink.ink)
        Text(label, style = Type.small, color = Ink.ink3)
    }
}
