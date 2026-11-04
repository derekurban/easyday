// Feature flags, read from the build flavour. The prototype tools (clock shift, simulated workouts, erase
// everything) ship in staging only; prod builds hide them and run on the real clock. The playground (ideas tried
// before they reach the app) is for development only: debug builds, never a release, staging or prod.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show appFlavor;

/// Whether a build of [flavor] carries the prototype tools: staging only.
bool prototypeToolsFor(String? flavor) => flavor == 'staging';

/// This build's prototype tools flag.
final bool prototypeTools = prototypeToolsFor(appFlavor);

/// Whether this build shows the playground tab: debug builds only, the dev loops on the emulator and the phone.
const bool playgroundTab = kDebugMode;
