package dev.derekurban.fitness

import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.CalendarContract
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.TimeZone

/// Hosts two small channels: the calendar (permissions, today's events, the writable calendars, writing one event)
/// and the updater (what build this is, the install permission, and handing a downloaded APK to the installer).
class MainActivity : FlutterActivity() {
    private var pendingPermission: MethodChannel.Result? = null
    private var pendingWrite: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitness/calendar").setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasReadPermission())
                "requestPermission" -> {
                    if (hasReadPermission()) { result.success(true); return@setMethodCallHandler }
                    pendingPermission?.success(false)
                    pendingPermission = result
                    ActivityCompat.requestPermissions(this, arrayOf(android.Manifest.permission.READ_CALENDAR), CALENDAR_REQUEST)
                }
                "hasWritePermission" -> result.success(hasWritePermission())
                "requestWritePermission" -> {
                    if (hasWritePermission()) { result.success(true); return@setMethodCallHandler }
                    pendingWrite?.success(false)
                    pendingWrite = result
                    ActivityCompat.requestPermissions(this, arrayOf(android.Manifest.permission.READ_CALENDAR, android.Manifest.permission.WRITE_CALENDAR), CALENDAR_WRITE_REQUEST)
                }
                "eventsToday" -> result.success(eventsToday())
                "calendars" -> result.success(calendars())
                "writeEvent" -> result.success(writeEvent(
                    call.argument<Number>("calendarId")?.toLong(), call.argument<Number>("eventId")?.toLong(),
                    call.argument<Number>("begin")!!.toLong(), call.argument<Number>("end")!!.toLong(),
                    call.argument<String>("title") ?: "Workout", call.argument<String>("description") ?: ""))
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fitness/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "appInfo" -> {
                    val pi = packageManager.getPackageInfo(packageName, 0)
                    val code = if (Build.VERSION.SDK_INT >= 28) pi.longVersionCode else @Suppress("DEPRECATION") pi.versionCode.toLong()
                    result.success(mapOf("versionName" to (pi.versionName ?: ""), "versionCode" to code, "flavor" to BuildConfig.FLAVOR, "package" to packageName))
                }
                "canInstall" -> result.success(Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls())
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= 26) startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                    result.success(true)
                }
                "cacheDir" -> result.success(File(cacheDir, "updates").apply { mkdirs() }.absolutePath)
                "install" -> result.success(installApk(call.argument<String>("path")!!))
                else -> result.notImplemented()
            }
        }
    }

    /// Opens the package installer on an APK in our cache, through the FileProvider declared in the manifest.
    private fun installApk(path: String): Boolean = try {
        val uri = FileProvider.getUriForFile(this, "$packageName.files", File(path))
        startActivity(Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/vnd.android.package-archive")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (e: Exception) {
        false
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CALENDAR_REQUEST) {
            pendingPermission?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            pendingPermission = null
        }
        if (requestCode == CALENDAR_WRITE_REQUEST) {
            pendingWrite?.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
            pendingWrite = null
        }
    }

    private fun hasReadPermission() =
        ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED

    private fun hasWritePermission() = hasReadPermission() &&
        ContextCompat.checkSelfPermission(this, android.Manifest.permission.WRITE_CALENDAR) == PackageManager.PERMISSION_GRANTED

    /// Today's instances, midnight to midnight local time, or null without permission. The awake window is applied in Dart.
    private fun eventsToday(): List<Map<String, Any?>>? {
        if (!hasReadPermission()) return null
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val end = start + 24L * 60 * 60 * 1000
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().appendPath(start.toString()).appendPath(end.toString()).build()
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID, CalendarContract.Instances.BEGIN, CalendarContract.Instances.END,
            CalendarContract.Instances.ALL_DAY, CalendarContract.Instances.SELF_ATTENDEE_STATUS, CalendarContract.Instances.TITLE)
        val out = mutableListOf<Map<String, Any?>>()
        try {
            contentResolver.query(uri, projection, null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    out.add(mapOf(
                        "id" to c.getLong(0), "begin" to c.getLong(1), "end" to c.getLong(2),
                        "allDay" to (c.getInt(3) == 1),
                        "declined" to (c.getInt(4) == CalendarContract.Attendees.ATTENDEE_STATUS_DECLINED),
                        "title" to (c.getString(5) ?: "")))
                }
            }
        } catch (e: Exception) {
            return null
        }
        return out
    }

    /// The calendars the app may write to.
    private fun calendars(): List<Map<String, Any?>> {
        if (!hasReadPermission()) return emptyList()
        val projection = arrayOf(
            CalendarContract.Calendars._ID, CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.IS_PRIMARY, CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL)
        val out = mutableListOf<Map<String, Any?>>()
        try {
            contentResolver.query(CalendarContract.Calendars.CONTENT_URI, projection, null, null, null)?.use { c ->
                while (c.moveToNext()) {
                    if (c.getInt(4) < CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR) continue
                    out.add(mapOf("id" to c.getLong(0), "name" to (c.getString(1) ?: ""), "account" to (c.getString(2) ?: ""), "primary" to (c.getInt(3) == 1)))
                }
            }
        } catch (e: Exception) {
            return emptyList()
        }
        return out
    }

    /// Insert or update one event the app owns. Returns its id, or null.
    private fun writeEvent(calendarId: Long?, eventId: Long?, begin: Long, end: Long, title: String, description: String): Long? {
        if (!hasWritePermission()) return null
        val target = calendarId ?: calendars().let { list -> (list.firstOrNull { it["primary"] == true } ?: list.firstOrNull())?.get("id") as Long? } ?: return null
        val values = ContentValues().apply {
            put(CalendarContract.Events.CALENDAR_ID, target)
            put(CalendarContract.Events.DTSTART, begin)
            put(CalendarContract.Events.DTEND, end)
            put(CalendarContract.Events.TITLE, title)
            put(CalendarContract.Events.DESCRIPTION, description)
            put(CalendarContract.Events.EVENT_TIMEZONE, TimeZone.getDefault().id)
            put(CalendarContract.Events.AVAILABILITY, CalendarContract.Events.AVAILABILITY_FREE)
        }
        return try {
            if (eventId != null) {
                val rows = contentResolver.update(android.content.ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId), values, null, null)
                if (rows > 0) eventId else contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)?.lastPathSegment?.toLongOrNull()
            } else {
                contentResolver.insert(CalendarContract.Events.CONTENT_URI, values)?.lastPathSegment?.toLongOrNull()
            }
        } catch (e: Exception) {
            null
        }
    }

    companion object { const val CALENDAR_REQUEST = 4210; const val CALENDAR_WRITE_REQUEST = 4211 }
}
