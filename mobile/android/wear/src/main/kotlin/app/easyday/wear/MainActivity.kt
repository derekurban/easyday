package app.easyday.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch

/// The one screen: whatever the phone's view says (Ui.kt). Opening it asks the phone for its view, and while a workout
/// is under way it starts recording the heart rate (WorkoutService).
class MainActivity : ComponentActivity() {
    private val ask = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { record() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // debug builds take a made-up view, for screenshots without a phone: --es demo lift
        if (BuildConfig.DEBUG) intent.getStringExtra("demo")?.let { Demo.show(it) }
        setContent { EasydayTheme { App(send = { op, extra -> Link.send(this, op, extra) }) } }
        lifecycleScope.launch { Link.view.collect { record() } }
    }

    override fun onStart() {
        super.onStart()
        if (Demo.on) return
        Link.load(this)
        Link.hello(this)
        val prefs = getSharedPreferences("easyday", MODE_PRIVATE)
        if (!WorkoutService.canRead(this) && !prefs.getBoolean("asked", false)) {
            prefs.edit().putBoolean("asked", true).apply()
            ask.launch(WorkoutService.permissions())
        }
    }

    override fun onResume() {
        super.onResume()
        visible = true
        record()
    }

    override fun onPause() {
        visible = false
        super.onPause()
    }

    /// A workout under way on the phone, the app on screen and the sensor allowed: record it.
    private fun record() {
        val v = Link.view.value ?: return
        val id = v.session ?: return
        if (visible && v.record && (!Demo.on || Demo.live) && WorkoutService.canRead(this)) WorkoutService.start(this, id)
    }

    companion object {
        @Volatile var visible = false
    }
}
