// Notifications, calendar and location. Each is off until the user turns it on in Settings and grants the permission.
// Every call here is safe to make on a platform without the capability: it returns false, null or an empty list.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'data/model.dart';
import 'logic/calendar.dart';
import 'logic/update.dart';

class Notifications {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _reminderId = 1;
  static const _channel = AndroidNotificationDetails('workouts', 'Workout reminders',
      channelDescription: 'One reminder a day, at the hour you chose, only when a workout is waiting.', importance: Importance.defaultImportance, priority: Priority.defaultPriority);

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (e) {
      debugPrint('timezone: $e');
    }
    try {
      await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      _ready = true;
    } catch (e) {
      debugPrint('notifications: $e');
    }
  }

  static Future<bool> requestPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.requestNotificationsPermission();
      return ok ?? false;
    } catch (e) {
      debugPrint('notifications permission: $e');
      return false;
    }
  }

  static Future<bool> hasPermission() async {
    await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// A daily reminder at [hour]. The text is the same every day on purpose: one line, no guilt.
  static Future<void> scheduleDaily(int hour) async {
    await init();
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _reminderId);
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      await _plugin.zonedSchedule(id: _reminderId, title: 'Your workout is ready', body: 'Two questions and a start button. Easy counts.', scheduledDate: at,
          notificationDetails: const NotificationDetails(android: _channel), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, matchDateTimeComponents: DateTimeComponents.time);
    } catch (e) {
      debugPrint('schedule: $e');
    }
  }

  static Future<void> cancel() async {
    await init();
    try { await _plugin.cancel(id: _reminderId); } catch (_) {}
  }

  /// Show one notification now. Used for the test button in Settings.
  static Future<void> showNow(String title, String body) async {
    await init();
    if (!_ready) return;
    try { await _plugin.show(id: 2, title: title, body: body, notificationDetails: const NotificationDetails(android: _channel)); } catch (e) { debugPrint('show: $e'); }
  }
}

class CalendarInfo {
  const CalendarInfo({required this.id, required this.name, required this.account, required this.primary});
  final String id;
  final String name;
  final String account;
  final bool primary;
}

class CalendarBridge {
  static const _ch = MethodChannel('fitness/calendar');

  static Future<bool> hasPermission() async {
    try { return await _ch.invokeMethod<bool>('hasPermission') ?? false; } catch (_) { return false; }
  }

  static Future<bool> requestPermission() async {
    try { return await _ch.invokeMethod<bool>('requestPermission') ?? false; } catch (_) { return false; }
  }

  static Future<bool> hasWritePermission() async {
    try { return await _ch.invokeMethod<bool>('hasWritePermission') ?? false; } catch (_) { return false; }
  }

  static Future<bool> requestWritePermission() async {
    try { return await _ch.invokeMethod<bool>('requestWritePermission') ?? false; } catch (_) { return false; }
  }

  /// Today's event instances, midnight to midnight, or null without permission.
  static Future<List<CalEvent>?> eventsToday() async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('eventsToday');
      if (raw == null) return null;
      return [
        for (final e in raw.cast<Map<dynamic, dynamic>>())
          CalEvent(
            id: (e['id'] as num).toInt(),
            begin: DateTime.fromMillisecondsSinceEpoch((e['begin'] as num).toInt()),
            end: DateTime.fromMillisecondsSinceEpoch((e['end'] as num).toInt()),
            allDay: e['allDay'] == true, declined: e['declined'] == true, title: (e['title'] as String?) ?? '',
          ),
      ];
    } catch (e) {
      debugPrint('calendar events: $e');
      return null;
    }
  }

  /// The writable calendars on the phone.
  static Future<List<CalendarInfo>> calendars() async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('calendars') ?? const [];
      return [
        for (final c in raw.cast<Map<dynamic, dynamic>>())
          CalendarInfo(id: '${c['id']}', name: (c['name'] as String?) ?? '', account: (c['account'] as String?) ?? '', primary: c['primary'] == true),
      ];
    } catch (e) {
      debugPrint('calendars: $e');
      return const [];
    }
  }

  /// Write or rewrite an event on [calendarId] (null: the primary). Returns the event id, or null when it could not.
  static Future<int?> writeEvent({String? calendarId, int? eventId, required DateTime begin, required DateTime end, required String title, required String description}) async {
    try {
      final id = await _ch.invokeMethod<int>('writeEvent', {
        'calendarId': calendarId == null ? null : int.tryParse(calendarId), 'eventId': eventId,
        'begin': begin.millisecondsSinceEpoch, 'end': end.millisecondsSinceEpoch, 'title': title, 'description': description,
      });
      return id;
    } catch (e) {
      debugPrint('calendar write: $e');
      return null;
    }
  }
}

/// The app's copy of today's calendar: read on open, on resume, after a write, and when the user asks. Never on a timer.
class CalendarSync {
  static DayShape? day;
  static DateTime? syncedAt;
  static List<CalendarInfo> calendars = const [];

  /// Read today and reshape it. Returns the shape, or null when the calendar is off or not permitted.
  static Future<DayShape?> sync(AppState s, DateTime now) async {
    if (!s.settings.calendar) { day = null; return null; }
    final events = await CalendarBridge.eventsToday();
    if (events == null) { day = null; return null; }
    final ours = {for (final x in s.sessions) if (x.calendarEventId != null) x.calendarEventId!};
    day = shapeDay(events, s.settings, now, ourIds: ours);
    syncedAt = DateTime.now();
    return day;
  }

  static Future<void> loadCalendars() async {
    calendars = await CalendarBridge.calendars();
  }

  static String agoText(DateTime now) {
    final at = syncedAt;
    if (at == null) return 'not synced yet';
    final m = now.difference(at).inMinutes;
    return m < 1 ? 'synced just now' : m < 60 ? 'synced $m min ago' : 'synced ${m ~/ 60} h ago';
  }
}

class Position2 {
  const Position2(this.lat, this.lng);
  final double lat;
  final double lng;
}

class LocationBridge {
  static Future<bool> hasPermission() async {
    try {
      final p = await Geolocator.checkPermission();
      return p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      return p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  static Future<Position2?> current() async {
    try {
      if (!await hasPermission()) return null;
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)));
      return Position2(p.latitude, p.longitude);
    } catch (e) {
      debugPrint('location: $e');
      return null;
    }
  }

  /// Within this many metres of a saved position, the location is picked for you.
  static const nearbyMetres = 400.0;

  /// Metres from [here] to a location with a position, or null for an anywhere location.
  static double? distance(Location l, Position2 here) => l.hasPosition ? Geolocator.distanceBetween(here.lat, here.lng, l.lat!, l.lng!) : null;

  static String distanceText(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(m < 10000 ? 1 : 0)} km';

  /// The saved location nearest to [here], if any is within [withinMetres].
  static Location? nearest(List<Location> locations, Position2 here, {double withinMetres = nearbyMetres}) {
    Location? best;
    var bestD = withinMetres;
    for (final l in locations) {
      final d = distance(l, here);
      if (d != null && d <= bestD) { best = l; bestD = d; }
    }
    return best;
  }
}

/// What build is installed, from the package manager.
class AppInfo {
  const AppInfo({required this.versionName, required this.versionCode, required this.flavor, required this.package});
  final String versionName;
  final int versionCode;
  final String flavor;
  final String package;
}

/// The updater: GitHub's latest release, a download into the app cache, and the Android installer.
class UpdateBridge {
  static const _ch = MethodChannel('fitness/update');

  static Future<AppInfo?> appInfo() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('appInfo');
      if (m == null) return null;
      return AppInfo(versionName: m['versionName'] as String? ?? '', versionCode: (m['versionCode'] as num?)?.toInt() ?? 0,
          flavor: m['flavor'] as String? ?? 'prod', package: m['package'] as String? ?? '');
    } catch (_) { return null; }
  }

  /// The newest release on GitHub carrying [flavor]'s APK. `reachable` is false when the request itself failed; a
  /// reachable answer with no release means nothing has been published yet.
  static Future<({ReleaseInfo? release, bool reachable})> latest(String? flavor) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(releasesUrl));
      req.headers.set(HttpHeaders.userAgentHeader, 'fitness-app');
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final res = await req.close();
      final body = await res.transform(const Utf8Decoder()).join();
      if (res.statusCode == 404) return (release: null, reachable: true);
      if (res.statusCode != 200) return (release: null, reachable: false);
      return (release: pickRelease(body, flavor), reachable: true);
    } catch (_) {
      return (release: null, reachable: false);
    } finally {
      client.close();
    }
  }

  static Future<bool> canInstall() async {
    try { return await _ch.invokeMethod<bool>('canInstall') ?? false; } catch (_) { return false; }
  }

  static Future<void> openInstallSettings() async {
    try { await _ch.invokeMethod<bool>('openInstallSettings'); } catch (_) {}
  }

  /// Downloads [url] into the app's update cache as [name], reporting 0..1, and returns the file path.
  static Future<String?> download(String url, String name, void Function(double) onProgress) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final dir = await _ch.invokeMethod<String>('cacheDir');
      if (dir == null) return null;
      final file = File('$dir/$name');
      final req = await client.getUrl(Uri.parse(url));
      req.followRedirects = true;
      req.headers.set(HttpHeaders.userAgentHeader, 'fitness-app');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final total = res.contentLength;
      var got = 0;
      final sink = file.openWrite();
      await for (final chunk in res) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
      await sink.close();
      onProgress(1);
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  static Future<bool> install(String path) async {
    try { return await _ch.invokeMethod<bool>('install', {'path': path}) ?? false; } catch (_) { return false; }
  }
}
