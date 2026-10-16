import io
p = 'lib/data/model.dart'
s = io.open(p, encoding='utf-8').read()

def rep(a, b):
    global s
    assert a in s, a[:70]
    s = s.replace(a, b)

rep("enum StopReason { energy, time, pain }", "enum StopReason { energy, time, pain, none }")

rep("""  int painRestDays = 7;  // days a pattern rests after pain (3 to 28)

  Map<String, dynamic> toJson() => {'stepUp': stepUp, 'stepDown': stepDown, 'decayWeeks': decayWeeks, 'daysAway': daysAway, 'painRestDays': painRestDays};
  static Settings fromJson(Map<String, dynamic> j) => Settings()
    ..stepUp = j['stepUp'] ?? 1
    ..stepDown = j['stepDown'] ?? 2
    ..decayWeeks = j['decayWeeks'] ?? 3
    ..daysAway = j['daysAway'] ?? 7
    ..painRestDays = j['painRestDays'] ?? 7;
}""", """  int painRestDays = 7;  // days a pattern rests after pain (3 to 28)
  // integrations, each off until the user turns it on and grants the permission
  bool notify = false;
  int notifyHour = 18;   // daily reminder hour, 0 to 23
  bool calendar = false;
  bool location = false;
  bool circuit = false;  // last chosen workout mode

  Map<String, dynamic> toJson() => {
        'stepUp': stepUp, 'stepDown': stepDown, 'decayWeeks': decayWeeks, 'daysAway': daysAway, 'painRestDays': painRestDays,
        'notify': notify, 'notifyHour': notifyHour, 'calendar': calendar, 'location': location, 'circuit': circuit,
      };
  static Settings fromJson(Map<String, dynamic> j) => Settings()
    ..stepUp = j['stepUp'] ?? 1
    ..stepDown = j['stepDown'] ?? 2
    ..decayWeeks = j['decayWeeks'] ?? 3
    ..daysAway = j['daysAway'] ?? 7
    ..painRestDays = j['painRestDays'] ?? 7
    ..notify = j['notify'] ?? false
    ..notifyHour = j['notifyHour'] ?? 18
    ..calendar = j['calendar'] ?? false
    ..location = j['location'] ?? false
    ..circuit = j['circuit'] ?? false;
}""")

rep("""class Location {
  Location({required this.id, required this.name, required this.template, required this.equipment});
  String id;
  String name;
  String template;
  List<String> equipment;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'template': template, 'equipment': equipment};
  static Location fromJson(Map<String, dynamic> j) =>
      Location(id: j['id'], name: j['name'], template: j['template'], equipment: List<String>.from(j['equipment']));
}""", """class Location {
  Location({required this.id, required this.name, required this.template, required this.equipment, this.lat, this.lng});
  String id;
  String name;
  String template;
  List<String> equipment;
  double? lat;           // saved position, for picking the nearest location
  double? lng;
  bool get hasPosition => lat != null && lng != null;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'template': template, 'equipment': equipment, 'lat': lat, 'lng': lng};
  static Location fromJson(Map<String, dynamic> j) => Location(
      id: j['id'], name: j['name'], template: j['template'], equipment: List<String>.from(j['equipment']),
      lat: (j['lat'] as num?)?.toDouble(), lng: (j['lng'] as num?)?.toDouble());
}""")

rep("""    this.kind, this.exercises = const [], this.minutes, this.routine, this.cardio, this.estMinutes = 0, this.bonusCardioMinutes,
  });""", """    this.kind, this.exercises = const [], this.minutes, this.routine, this.cardio, this.estMinutes = 0, this.bonusCardioMinutes, this.circuit = false,
  });""")

rep("""  int estMinutes;
  int? bonusCardioMinutes;
  DateTime? startedAt;""", """  int estMinutes;
  int? bonusCardioMinutes;
  bool circuit;          // one set of each exercise per round, instead of all sets of one exercise
  List<int> skipped = [];
  DateTime? startedAt;""")

rep("""        'feel': feel == null ? null : _e(feel!), 'note': note, 'swappedToMove': swappedToMove,
      };""", """        'feel': feel == null ? null : _e(feel!), 'note': note, 'swappedToMove': swappedToMove, 'circuit': circuit, 'skipped': skipped,
      };""")

rep("""        minutes: j['minutes'], routine: j['routine'], cardio: j['cardio'], estMinutes: j['estMinutes'] ?? 0, bonusCardioMinutes: j['bonusCardioMinutes'],
      )
    ..effort = j['effort']""", """        minutes: j['minutes'], routine: j['routine'], cardio: j['cardio'], estMinutes: j['estMinutes'] ?? 0, bonusCardioMinutes: j['bonusCardioMinutes'],
        circuit: j['circuit'] ?? false,
      )
    ..skipped = List<int>.from(j['skipped'] ?? [])
    ..effort = j['effort']""")

rep("""  Energy energyDefault = Energy.normal;
  int timeDefault = minutesDefault;
  Map<String, dynamic> toJson() => {
        'rotation': rotation.map((r) => r.toJson()).toList(), 'index': index,
        'paused': paused.map((k, v) => MapEntry(k, _ms(v))), 'energyDefault': _e(energyDefault), 'timeDefault': timeDefault,
      };""", """  Energy energyDefault = Energy.normal;
  int timeDefault = minutesDefault;
  DateTime? continuedOn;  // the day the user chose to start another workout after finishing one
  Map<String, dynamic> toJson() => {
        'rotation': rotation.map((r) => r.toJson()).toList(), 'index': index,
        'paused': paused.map((k, v) => MapEntry(k, _ms(v))), 'energyDefault': _e(energyDefault), 'timeDefault': timeDefault, 'continuedOn': _ms(continuedOn),
      };""")

rep("""    ..energyDefault = _p(Energy.values, j['energyDefault'], Energy.normal)
    ..timeDefault = j['timeDefault'] is int ? j['timeDefault'] : minutesDefault;""", """    ..energyDefault = _p(Energy.values, j['energyDefault'], Energy.normal)
    ..timeDefault = j['timeDefault'] is int ? j['timeDefault'] : minutesDefault
    ..continuedOn = _d(j['continuedOn']);""")

rep("""  int seq = 0;                   // id counter
  bool seenHow = false;          // the "how it works" page was shown
""", """  int seq = 0;                   // id counter
  bool seenHow = false;          // the "how it works" page was shown
  List<Exercise> custom = [];    // exercises the user made
""")

rep("""        'sessions': sessions.map((s) => s.toJson()).toList(), 'active': active?.toJson(), 'clockOffsetDays': clockOffsetDays, 'dev': dev, 'seq': seq, 'seenHow': seenHow,
      };""", """        'sessions': sessions.map((s) => s.toJson()).toList(), 'active': active?.toJson(), 'clockOffsetDays': clockOffsetDays, 'dev': dev, 'seq': seq, 'seenHow': seenHow,
        'custom': custom.map((e) => e.toJson()).toList(),
      };""")

rep("""  static AppState fromJson(Map<String, dynamic> j) {
    final s = AppState()""", """  static AppState fromJson(Map<String, dynamic> j) {
    final custom = ((j['custom'] ?? []) as List).map((e) => Exercise.fromJson(e)).toList();
    setCustomExercises(custom);
    final s = AppState()
      ..custom = custom""")

io.open(p, 'w', encoding='utf-8').write(s)
print('model ok')
