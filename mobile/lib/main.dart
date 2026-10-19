import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'data/store.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Debug builds publish the semantics tree so adb's uiautomator can read labels and tap targets.
  if (kDebugMode) SemanticsBinding.instance.ensureSemantics();
  final store = await Store.open();
  runApp(EasydayApp(store));
}
