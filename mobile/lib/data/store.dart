// Persistence and the shifted clock. One JSON blob in shared preferences.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model.dart';

const _key = 'fitness.v2';

class Store extends ChangeNotifier {
  Store(this.state, this._prefs);
  AppState state;
  final SharedPreferences? _prefs;

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

  DateTime get now => DateTime.now().add(Duration(days: state.clockOffsetDays));

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
}
