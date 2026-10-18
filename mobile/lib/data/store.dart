// Persistence and the shifted clock. One JSON blob in shared preferences.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features.dart';
import 'model.dart';

const _key = 'fitness.v2';

class Store extends ChangeNotifier {
  Store(this.state, this._prefs, {bool? shiftClock}) : shiftClock = shiftClock ?? prototypeTools;
  AppState state;
  final SharedPreferences? _prefs;
  /// Whether the prototype clock shift applies. Off in prod, so a shift saved by an older build is ignored there.
  final bool shiftClock;

  static Future<Store> open() async {
    SharedPreferences? prefs;
    AppState state;
    try {
      prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      state = raw == null ? AppState() : AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('store: starting fresh ($e)');
      state = AppState();
    }
    return Store(state, prefs);
  }

  DateTime get now => DateTime.now().add(Duration(days: shiftClock ? state.clockOffsetDays : 0));

  void save() {
    _prefs?.setString(_key, jsonEncode(state.toJson()));
    notifyListeners();
  }

  /// Mutate then persist and notify in one call.
  void update(void Function(AppState s) fn) {
    fn(state);
    save();
  }

  void reset() {
    state = AppState();
    save();
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(state.toJson());

  /// Whether [raw] is a copy made by [exportJson]: JSON with a profile and a plan, not just any text on the clipboard.
  static bool looksLikeData(String raw) {
    try {
      final j = jsonDecode(raw);
      return j is Map<String, dynamic> && j['profile'] is Map && j['plan'] is Map;
    } catch (_) {
      return false;
    }
  }

  /// Replaces everything with a copy made by [exportJson], from this install or another. False, with nothing changed,
  /// when [raw] is not one.
  bool importJson(String raw) {
    if (!looksLikeData(raw)) return false;
    try {
      state = AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('store: import failed ($e)');
      return false;
    }
    save();
    return true;
  }
}
