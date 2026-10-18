// Feature flags, read from the build flavour. The prototype tools (clock shift, simulated workouts, erase
// everything) ship in staging only; prod builds hide them and run on the real clock.
import 'package:flutter/services.dart' show appFlavor;

/// Whether a build of [flavor] carries the prototype tools: staging only.
bool prototypeToolsFor(String? flavor) => flavor == 'staging';

/// This build's prototype tools flag.
final bool prototypeTools = prototypeToolsFor(appFlavor);
