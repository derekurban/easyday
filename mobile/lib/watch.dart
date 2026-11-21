// The watch link: the phone end of Easyday on a Wear OS watch (docs/app/WATCH.md). The phone sends the watch what to
// show (logic/watch_view.dart) as one data item whenever it changes; the watch sends taps and heart rate as messages,
// which Android keeps in an inbox (WatchInbox.kt) until the app reads them, so nothing sent while the app was asleep
// is lost. The workout screen handles the taps itself, through the same code as its own buttons. Every call is safe
// without a watch, without Google Play services, and in tests: it does nothing.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'logic/heart.dart';
import 'logic/watch_view.dart';

class WatchLink {
  static const _ch = MethodChannel('easyday/watch');
  static Store? _store;
  static Timer? _soon;
  static String? _sent;   // the last map sent, so an unchanged one is not sent again
  static int _seq = 0;
  static bool _answer = false; // the next send answers the watch: it goes even when nothing changed

  /// The workout screen's handler for a tap from the watch, while it is up. True when it did something.
  static bool Function(Map<String, dynamic> cmd)? onCommand;

  /// The workout Today would start, while Today is on screen.
  static WatchToday? get today => _today;
  static set today(WatchToday? v) {
    final changed = v?.name != _today?.name || v?.detail != _today?.detail || (v?.start == null) != (_today?.start == null);
    _today = v;
    if (changed) _schedule();
  }
  static WatchToday? _today;

  /// Starts the link for [store]: sends the watch the state now and on every change, and reads the inbox now and
  /// whenever Android says something came in.
  static void attach(Store store) {
    _store = store;
    store.addListener(_schedule);
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'inbox') await _drain();
    });
    _drain();
    _schedule();
  }

  static void _schedule() {
    if (_store == null) return; // not attached (tests, or before the app opened its store)
    _soon?.cancel();
    _soon = Timer(const Duration(milliseconds: 120), publish);
  }

  /// Sends what the watch shows, unless it is what was sent last. [force] sends it anyway, as an answer to the watch.
  static Future<void> publish({bool force = false}) async {
    final store = _store;
    if (store == null) return;
    final skew = store.now.difference(DateTime.now()).inMilliseconds;
    final view = watchView(store.state, store.now, today: _today, skewMs: skew);
    final body = jsonEncode(view);
    force = force || _answer;
    _answer = false;
    if (!force && body == _sent) return;
    _sent = body;
    // the sequence makes every send a change, so the watch hears an answer even when nothing moved
    final withSeq = jsonEncode({...view, 'seq': ++_seq, 'sentAt': DateTime.now().millisecondsSinceEpoch});
    try {
      await _ch.invokeMethod<bool>('publish', {'json': withSeq});
    } catch (e) {
      debugPrint('watch publish: $e');
    }
  }

  static Future<void> _drain() async {
    List<dynamic> raw;
    try {
      raw = await _ch.invokeMethod<List<dynamic>>('takeInbox') ?? const [];
    } catch (_) {
      return;
    }
    for (final m in raw) {
      try {
        final msg = Map<String, dynamic>.from(m as Map);
        final data = jsonDecode(msg['data'] as String) as Map<String, dynamic>;
        switch (msg['path']) {
          case '/easyday/cmd': _command(data);
          case '/easyday/heart': _heart(data);
        }
      } catch (e) {
        debugPrint('watch inbox: $e');
      }
    }
  }

  static void _command(Map<String, dynamic> cmd) {
    final store = _store;
    if (store == null) return;
    var handled = false;
    if (watchCommandApplies(store.state, cmd, store.now, today: _today)) {
      switch (cmd['op']) {
        case 'hello':
          break;
        case 'start':
          _today?.start?.call();
          handled = true;
        default:
          handled = onCommand?.call(cmd) ?? false;
      }
    }
    // the watch waits for an answer: what it shows now, whether the tap did anything or not
    _answer = true;
    if (handled) { _schedule(); } else { publish(); }
  }

  /// A batch of heart rate from the watch, for the workout it names: the one under way, or one already logged.
  static void _heart(Map<String, dynamic> data) {
    final store = _store;
    if (store == null) return;
    final id = data['session'];
    final s = store.state;
    final x = s.active?.id == id ? s.active : s.sessions.where((x) => x.id == id).lastOrNull;
    if (x == null) return;
    final skew = store.now.difference(DateTime.now());
    final samples = [
      for (final p in (data['samples'] as List? ?? const []))
        (DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()).add(skew), (p[1] as num).round()),
    ];
    store.update((_) => addHeart(x, samples, kcal: (data['kcal'] as num?)?.toDouble(), device: data['device'] as String?));
  }
}
