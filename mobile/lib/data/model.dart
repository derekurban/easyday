// App state: what is persisted. Plain classes with hand-written JSON. No logic here beyond defaults.
import 'dart:math';

import 'index.dart';
import 'library.dart';

enum Energy { easy, normal, hard }
enum StopReason { energy, time, pain, none }
enum Feel { easy, right, tooMuch }
enum PersonState { active, atRisk, away }

String _e(Enum e) => e.name;
T _p<T extends Enum>(List<T> values, Object? v, T def) => values.firstWhere((x) => x.name == v, orElse: () => def);
DateTime? _d(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch(v as int);
int? _ms(DateTime? d) => d?.millisecondsSinceEpoch;

const energyLabel = {Energy.easy: 'Easy', Energy.normal: 'Normal', Energy.hard: 'Hard'};
const stateLabel = {PersonState.active: 'Active', PersonState.atRisk: 'At risk', PersonState.away: 'Away'};

/// The time question is minutes on a slider.
const minutesMin = 10;
const minutesMax = 120;
const minutesStep = 5;
const minutesDefault = 35;

int clampMinutes(int m) => ((m / minutesStep).round() * minutesStep).clamp(minutesMin, minutesMax);

/// The settings of section 9, plus the three integrations and their own settings.
class Settings {
  int stepUp = 1;        // sessions at the top before a rung steps up (1 to 5)
  int stepDown = 2;      // sessions below the bottom before a rung steps down (1 to 5)
  int decayWeeks = 3;    // weeks before an unused rung decays (2 to 8, 0 = off)
  int daysAway = 7;      // days away before easy is the default (5 to 21)
  int painRestDays = 7;  // days an exercise and its muscles rest after pain (3 to 28)
  // integrations, each off until the user turns it on and grants the permission
  bool notify = false;
  int notifyHour = 18;   // daily reminder hour, 0 to 23
  bool calendar = false;
  int awakeStart = 8 * 60;   // the awake window, minutes of the day
  int awakeEnd = 22 * 60;
  bool busyAdjust = true;    // a busy day makes a lighter day
  int busyShort = 50;        // busy share of the awake window that shortens the default, 30 to 90
  int busyEasy = 70;         // busy share that also makes the default easy, busyShort to 100
  bool autoTrack = false;    // write finished workouts to the calendar
  String? calendarId;        // the calendar to write to; null is the phone's primary
  bool location = false;
  bool circuit = false;  // last chosen workout mode
  bool timeLimit = true; // last chosen on Today: fit the workout to the minutes, or pick a number of exercises
  int warmup = 5;        // last chosen warm-up block, minutes (0 = none)
  bool restAuto = false; // when the planned rest runs out, start the next set as if I'm ready was tapped
  bool timeAsShare = false; // show lifting and rest as a share of the time, not minutes
  ExerciseIndex index = ExerciseIndex.muscle;  // how the library is grouped for browsing
  String figure = 'male';    // the body map figure: male or female

  Map<String, dynamic> toJson() => {
        'stepUp': stepUp, 'stepDown': stepDown, 'decayWeeks': decayWeeks, 'daysAway': daysAway, 'painRestDays': painRestDays,
        'notify': notify, 'notifyHour': notifyHour, 'calendar': calendar, 'awakeStart': awakeStart, 'awakeEnd': awakeEnd,
        'busyAdjust': busyAdjust, 'busyShort': busyShort, 'busyEasy': busyEasy, 'autoTrack': autoTrack, 'calendarId': calendarId,
        'location': location, 'circuit': circuit, 'timeLimit': timeLimit, 'warmup': warmup, 'restAuto': restAuto, 'timeAsShare': timeAsShare,
        'index': _e(index), 'figure': figure,
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
    ..awakeStart = j['awakeStart'] ?? 8 * 60
    ..awakeEnd = j['awakeEnd'] ?? 22 * 60
    ..busyAdjust = j['busyAdjust'] ?? true
    ..busyShort = j['busyShort'] ?? 50
    ..busyEasy = j['busyEasy'] ?? 70
    ..autoTrack = j['autoTrack'] ?? false
    ..calendarId = j['calendarId']
    ..location = j['location'] ?? false
    ..circuit = j['circuit'] ?? false
    ..timeLimit = j['timeLimit'] ?? true
    ..warmup = j['warmup'] ?? 5
    ..restAuto = j['restAuto'] ?? false
    ..timeAsShare = j['timeAsShare'] ?? false
    ..index = _p(ExerciseIndex.values, j['index'], ExerciseIndex.muscle)
    ..figure = j['figure'] == 'female' ? 'female' : 'male';
}

/// What spare minutes are for, once the planned exercises fit.
enum Spare { exercises, cardio, rest }

/// How often an unrated exercise takes a turn from a practised one: one appearance in eight, four or two (SELECTION.md).
enum Explore { rarely, sometimes, often }

const exploreLabel = {Explore.rarely: 'Rarely', Explore.sometimes: 'Sometimes', Explore.often: 'Often'};
const exploreRun = {Explore.rarely: 8, Explore.sometimes: 4, Explore.often: 2};
/// Emphasis per muscle group: less, usual, more, as a share of the sets target.
const emphasisLabel = {-1: 'Less', 0: 'Usual', 1: 'More'};
/// How often an active muscle's turn comes round, against its plain turn: less is half as often, more twice.
const oftenLabel = {-1: 'Less', 0: 'Usual', 1: 'More'};
const oftenFactor = {-1: 0.5, 0: 1.0, 1: 2.0};


/// The sets target per muscle group seeded from days per week: 6 for two days, 8 for three, 10 for four or more.
int seedSetsTarget(int daysPerWeek) => daysPerWeek <= 2 ? 6 : daysPerWeek == 3 ? 8 : 10;

const spareLabel = {Spare.exercises: 'More exercises', Spare.cardio: 'Cardio', Spare.rest: 'Rest'};
const expressionLabel = {Expression.heavy: 'Heavy and few', Expression.middle: 'Middle', Expression.light: 'Light and many'};
const expressionRange = {Expression.heavy: heavyReps, Expression.middle: middleReps, Expression.light: lightReps};
/// An easy day's weight, as a share of the usual. Fixed for now; tunable later (IDEAS.md).
const easyShare = 0.85;
/// An easy day's lifting window, as a share of the normal one: fewer exercises at full sets, the rest is cardio or rest.
const easyWindowShare = 0.67;
/// The lightest share of a max any band lifts; the level steps the max by one plate step over it.
const lightestShare = 0.6;

/// Share of the level (an estimated max) a band lifts: the top of the range is about the max, by Epley.
double pctFor(RepRange r) => (1 / (1 + r.hi / 30)).clamp(lightestShare, 0.9);
/// Rest after a set, by band. Generous on purpose; the timing model replaces it.
int restFor(RepRange r) => r.hi <= 7 ? 180 : r.hi <= 12 ? 90 : 60;
const defaultCardioPct = 15;
const defaultStretchPct = 10;
/// The ranges of the three calibrations.
const exercisesMin = 1, exercisesMax = 10;
const setsMin = 1, setsMax = 6;
const pushesMin = 0, pushesMax = 10;

String rangeText(RepRange r) => '${r.lo} to ${r.hi}';
List<int> _rr(RepRange r) => [r.lo, r.hi];
RepRange _pr(dynamic v) => RepRange(v[0], v[1]);

/// The user's goal: their own, filled from a template if they like, every knob in plain words. See WORKOUT.md.
class GoalConfig {
  GoalConfig({
    required this.template, required this.name, required List<Band> bands, required this.exercises, required this.sets, required this.pushes,
    required this.moveEvery, this.spare = Spare.exercises, this.cardioPct = defaultCardioPct, this.stretchPct = defaultStretchPct,
    Map<String, int>? often, Map<String, MuscleTag>? tags, this.explore = Explore.rarely,
  }) : bands = [for (final b in bands) b.copy()], often = {...?often}, tags = {...?tags};
  String template;       // the template it was last filled from, for the icon
  String name;
  List<Band> bands;      // rep bands, each tagged with the difficulties it applies to; several per difficulty cycle by workout
  Tri exercises;         // different exercises in a workout: the fewest, the ideal, the most (1 to 10)
  Tri sets;              // working sets: the fewest, the usual, the most (1 to 6); progress is the level rising, never the sets
  Tri pushes;            // exercises at the next level on a hard day: on a tight day, usually, on a long day (0 to 10)
  int moveEvery;         // a movement day after every N lifting days (0 = none)
  Spare spare;           // what spare minutes are for
  int cardioPct;         // share of every workout's minutes for cardio at the end
  int stretchPct;        // share for stretching, last
  Map<String, int> often;         // muscle -> -1 less, 1 more often; absent is usual
  Map<String, MuscleTag> tags;    // muscle -> its tag where it differs from the template's default
  Explore explore;       // how often an unrated exercise takes a turn

  /// The working set count: the usual.
  int get workingSets => sets.ideal;

  /// How often a muscle's turn comes round: -1 less, 0 usual, 1 more.
  int oftenOf(String muscle) => often[muscle] ?? 0;

  void setOften(String muscle, int v) {
    if (v == 0) { often.remove(muscle); } else { often[muscle] = v.clamp(-1, 1); }
  }

  /// A muscle's tag: the user's, else the template's default (the shins ignored everywhere).
  MuscleTag tagOf(String muscle) => tags[muscle] ?? defaultTag(template, muscle);

  void setTag(String muscle, MuscleTag tag) {
    if (tag == defaultTag(template, muscle)) { tags.remove(muscle); } else { tags[muscle] = tag; }
  }

  /// The muscles that get exercises of their own, in the map's order.
  List<String> get activeMuscles => [for (final m in trackedMuscles) if (tagOf(m) == MuscleTag.active) m];
  List<String> get passiveMuscles => [for (final m in trackedMuscles) if (tagOf(m) == MuscleTag.passive) m];

  /// The bands for a difficulty, in list order.
  List<RepRange> rowFor(int difficulty) => [for (final b in bands) if (b.difficulties.contains(difficulty)) b.range];

  /// The rows per difficulty, easy first.
  Schemes get schemes => [for (var d = 1; d <= 3; d++) rowFor(d)];

  /// The band an exercise of this difficulty trains in on the nth lifting workout of the rotation. A difficulty with no
  /// band takes the nearest difficulty's, then the middle band.
  RepRange rangeForDifficulty(int difficulty, int liftIndex) {
    final d = difficulty.clamp(1, 3);
    for (final tryD in [d, d - 1, d + 1, d - 2, d + 2]) {
      if (tryD < 1 || tryD > 3) continue;
      final row = rowFor(tryD);
      if (row.isNotEmpty) return row[liftIndex % row.length];
    }
    return middleReps;
  }

  /// The named program these bands match, or null when edited by hand.
  String? get program => programBands.entries.where((e) => _sameBands(e.value(), bands)).map((e) => e.key).firstOrNull;

  static bool _sameBands(List<Band> a, List<Band> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) { if (a[i] != b[i]) return false; }
    return true;
  }

  static GoalConfig fromTemplate(Goal g) => GoalConfig(template: g.id, name: g.name, bands: g.bands(), exercises: g.exercises, sets: g.sets, pushes: g.pushes, moveEvery: g.moveEvery);

  /// Fill every knob from a template, keeping nothing.
  void fill(Goal g) {
    template = g.id;
    name = g.name;
    bands = g.bands();
    exercises = g.exercises;
    sets = g.sets;
    pushes = g.pushes;
    moveEvery = g.moveEvery;
    spare = Spare.exercises;
    cardioPct = defaultCardioPct;
    stretchPct = defaultStretchPct;
    often = {};
    tags = {};
    explore = Explore.rarely;
  }

  Map<String, dynamic> toJson() => {
        'template': template, 'name': name, 'bands': [for (final b in bands) {'r': _rr(b.range), 'd': b.difficulties.toList()..sort()}],
        'exercises': _tri(exercises), 'sets': _tri(sets), 'pushes': _tri(pushes), 'moveEvery': moveEvery,
        'spare': _e(spare), 'cardioPct': cardioPct, 'stretchPct': stretchPct,
        'often': often, 'tags': tags.map((k, v) => MapEntry(k, _e(v))), 'explore': _e(explore),
      };
  static GoalConfig fromJson(Map<String, dynamic> j) {
    final tpl = goals[j['template']];
    List<Band> bands;
    if (j['bands'] != null) {
      bands = [for (final b in (j['bands'] as List)) Band(_pr(b['r']), List<int>.from(b['d']))];
    } else if (j['schemes'] != null) {
      bands = _bandsFromSchemes([for (final row in (j['schemes'] as List)) [for (final r in (row as List)) _pr(r)]]);
    } else if (j['reps'] != null && tpl == null) {
      // older data: one preset shifted lighter for easier exercises, or the mixed flag
      final base = _p(Expression.values, j['reps'], Expression.middle);
      bands = j['mixed'] == true ? mixedBands() : _bandsFromSchemes([for (var d = 1; d <= 3; d++) [expressionRange[Expression.values[(base.index + (3 - d)).clamp(0, 2)]]!]]);
    } else {
      bands = (tpl ?? goals['muscle']!).bands();
    }
    final t = tpl ?? goals['muscle']!;
    // older data held one number each: the most exercises, the working sets, the hard-day count (0 = all)
    final int? oldEx = j['maxExercises'] ?? j['lifts'] ?? (j['mains'] == null ? null : (j['mains'] ?? 3) + (j['accs'] ?? 1));
    final int? oldSets = j['workingSets'];
    final int? oldExtras = j['extras'];
    return GoalConfig(
      template: j['template'] ?? 'custom', name: j['name'] ?? 'My goal', bands: bands,
      exercises: j['exercises'] != null ? _ptri(j['exercises']).clampTo(exercisesMin, exercisesMax) : oldEx != null ? Tri(max(1, oldEx ~/ 2), oldEx, oldEx).clampTo(exercisesMin, exercisesMax) : t.exercises,
      sets: j['sets'] != null ? _ptri(j['sets']).clampTo(setsMin, setsMax) : oldSets != null ? Tri(max(1, oldSets - 1), oldSets, oldSets).clampTo(setsMin, setsMax) : t.sets,
      pushes: j['pushes'] != null ? _ptri(j['pushes']).clampTo(pushesMin, pushesMax) : oldExtras != null ? (oldExtras == 0 ? const Tri(2, 5, 10) : Tri(max(0, oldExtras - 1), oldExtras, oldExtras + 1)).clampTo(pushesMin, pushesMax) : t.pushes,
      moveEvery: j['moveEvery'] ?? t.moveEvery, spare: _p(Spare.values, j['spare'], Spare.exercises),
      cardioPct: j['cardioPct'] ?? defaultCardioPct, stretchPct: j['stretchPct'] ?? defaultStretchPct,
      // emphasis was the old name for how often, and per group before selection ran on muscles
      often: _oftenFrom((j['often'] ?? j['emphasis']) as Map? ?? {}),
      tags: {
        for (final e in (j['tags'] as Map? ?? {}).entries)
          if (trackedMuscles.contains(e.key)) e.key as String: _p(MuscleTag.values, e.value, MuscleTag.active),
      },
      explore: _p(Explore.values, j['explore'], Explore.rarely),
    );
  }

  /// Rows per difficulty into tagged bands: hard first, so a shared band keeps its cycle position on the hard row.
  static List<Band> _bandsFromSchemes(Schemes rows) {
    final out = <Band>[];
    for (var d = 3; d >= 1; d--) {
      if (d - 1 >= rows.length) continue;
      for (final r in rows[d - 1]) {
        final existing = out.where((b) => b.range == r).firstOrNull;
        if (existing != null) { existing.difficulties.add(d); } else { out.add(Band(r, [d])); }
      }
    }
    return out;
  }
}

List<int> _tri(Tri t) => [t.min, t.ideal, t.max];
Tri _ptri(dynamic v) => Tri(v[0], v[1], v[2]);

class Profile {
  Profile({required this.experience, required this.daysPerWeek, required this.createdAt});
  String experience;
  int daysPerWeek;
  DateTime createdAt;
  Map<String, dynamic> toJson() => {'experience': experience, 'daysPerWeek': daysPerWeek, 'createdAt': _ms(createdAt)};
  static Profile fromJson(Map<String, dynamic> j) =>
      Profile(experience: j['experience'], daysPerWeek: j['daysPerWeek'], createdAt: _d(j['createdAt'])!);
}

class Location {
  Location({required this.id, required this.name, this.template = customLocation, required this.equipment, this.lat, this.lng});
  String id;
  String name;
  String template;
  List<String> equipment;
  double? lat;           // saved position, for picking the nearest location
  double? lng;
  bool get hasPosition => lat != null && lng != null;
  /// No fixed place: never picked by distance, the fallback when nothing is near.
  bool get anywhere => !hasPosition;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'template': template, 'equipment': equipment, 'lat': lat, 'lng': lng};
  static Location fromJson(Map<String, dynamic> j) => Location(
      id: j['id'], name: j['name'], template: j['template'] ?? customLocation, equipment: List<String>.from(j['equipment']),
      lat: (j['lat'] as num?)?.toDouble(), lng: (j['lng'] as num?)?.toDouble());
}

/// Everything the app knows about one exercise for this person: the rung, the streaks, the cost drift, the timing.
class ExerciseState {
  ExerciseState({required this.rung, required this.startRung, this.baseKg, required this.secPerSet});
  int rung;
  int startRung;          // decay never goes below this; a saved edit moves it
  double? baseKg;         // loaded exercises: the estimated max at rung 0; the level steps it, the expression picks the weight
  int topRun = 0;         // sessions in a row with every attempted set at the top
  int shortRun = 0;       // sessions in a row with a set below the bottom
  int appearances = 0;
  bool calibrating = true; // first appearance: an easy feel with every set at the top steps up at once
  int decayedBy = 0;      // rungs lost to decay still to be re-climbed
  int decayPeriodsApplied = 0;
  DateTime? lastDoneAt;
  int? costOverride;      // difficulty override 1 to 3, set on the card
  RepRange? repsOverride; // a rep band for this exercise regardless of the program, set on the card
  int costUp = 0;         // +1 while unpractised past the decay period
  int costDown = 0;       // cumulative drops from clearing a bodyweight ceiling
  int ceilingRun = 0;     // sessions in a row beating the best total at the ceiling
  int bestTotal = 0;      // best total reps at the current rung
  DateTime? lastWorkingAt; // last time the exercise was asked for its working level; the working turns go to the longest-waiting
  double secPerSet;       // timing model: seconds per set including the rest after it
  String? preference;     // the user's word: liked, fine, no (not for me); null is unrated (SELECTION.md)
  int swappedOut = 0;     // swapped out of a plan this many times in a row without being done; three ask "still like it?"
  DateTime? likedUntil;   // a manual pick of an unrated exercise counts as liked until then

  Map<String, dynamic> toJson() => {
        'rung': rung, 'startRung': startRung, 'baseKg': baseKg, 'topRun': topRun, 'shortRun': shortRun, 'appearances': appearances,
        'calibrating': calibrating, 'decayedBy': decayedBy, 'decayPeriodsApplied': decayPeriodsApplied, 'lastDoneAt': _ms(lastDoneAt),
        'costOverride': costOverride, 'costUp': costUp, 'costDown': costDown, 'ceilingRun': ceilingRun, 'bestTotal': bestTotal, 'secPerSet': secPerSet,
        'lastWorkingAt': _ms(lastWorkingAt), 'reps': repsOverride == null ? null : _rr(repsOverride!),
        'preference': preference, 'swappedOut': swappedOut, 'likedUntil': _ms(likedUntil),
      };
  static ExerciseState fromJson(Map<String, dynamic> j) => ExerciseState(
        rung: j['rung'], startRung: j['startRung'], baseKg: (j['baseKg'] as num?)?.toDouble(), secPerSet: (j['secPerSet'] as num).toDouble())
    ..topRun = j['topRun'] ?? 0
    ..shortRun = j['shortRun'] ?? 0
    ..appearances = j['appearances'] ?? 0
    ..calibrating = j['calibrating'] ?? false
    ..decayedBy = j['decayedBy'] ?? 0
    ..decayPeriodsApplied = j['decayPeriodsApplied'] ?? 0
    ..lastDoneAt = _d(j['lastDoneAt'])
    ..costOverride = j['costOverride'] == null ? null : (j['costOverride'] > 3 ? foldDifficulty(j['costOverride']) : j['costOverride'])
    ..costUp = j['costUp'] ?? 0
    ..costDown = j['costDown'] ?? 0
    ..ceilingRun = j['ceilingRun'] ?? 0
    ..bestTotal = j['bestTotal'] ?? 0
    ..lastWorkingAt = _d(j['lastWorkingAt'])
    ..repsOverride = j['reps'] != null ? _pr(j['reps']) : (j['band'] == null ? null : expressionRange[_p(Expression.values, j['band'], Expression.middle)])
    ..preference = const ['liked', 'fine', 'no'].contains(j['preference']) ? j['preference'] : null
    ..swappedOut = j['swappedOut'] ?? 0
    ..likedUntil = _d(j['likedUntil']);
}

/// One logged set. reps == null means never attempted. [start] is when the set began (I'm ready), [at] when the reps
/// went in; lifting is the time between them, rest everything else.
class SetLog {
  SetLog({this.reps, this.at, this.start});
  int? reps;
  DateTime? at;
  DateTime? start;
  bool get attempted => reps != null;
  /// Under way: started, reps not in yet.
  bool get lifting => start != null && reps == null;
  Map<String, dynamic> toJson() => {'reps': reps, 'at': _ms(at), 'start': _ms(start)};
  static SetLog fromJson(Map<String, dynamic> j) => SetLog(reps: j['reps'], at: _d(j['at']), start: _d(j['start']));
}

class Warmup {
  Warmup(this.reps, this.kg);
  final int reps;
  final double kg;
  Map<String, dynamic> toJson() => {'reps': reps, 'kg': kg};
  static Warmup fromJson(Map<String, dynamic> j) => Warmup(j['reps'], (j['kg'] as num).toDouble());
}

class SessionExercise {
  SessionExercise({
    required this.slot, required this.exId, required this.muscle, required this.intent, required this.workingSets, required this.rung, required this.rungLabel,
    required this.target, required this.lo, required this.hi, required this.atCeiling, required this.bestTotal, required this.difficulty,
    this.loadKg, required this.secPerSet, required this.sets, this.warmups = const [], this.edited = false, this.lightened = false,
    this.why = '', this.fresh = false, this.asked = false,
  });
  String slot;
  String exId;
  String muscle;      // the muscle group this exercise was chosen for (SELECTION.md)
  String why;         // one line on why it was chosen, from the ledgers and the user's word
  bool fresh;         // an unrated exercise took its turn for something new here
  bool asked;         // the user asked for this muscle by hand today
  String intent;      // light | working | extra: what today asks of this exercise. Never a judgement.
  int workingSets;    // the working set count at the time, so judging knows what the working level was
  int rung;           // the rung used today (after easy or comeback adjustments)
  String rungLabel;
  int target;         // reps (or seconds) to aim for in every set
  int lo;             // the range used for judgement
  int hi;
  bool atCeiling;
  int bestTotal;
  int difficulty;     // 1 to 3, in play
  double? loadKg;     // loaded exercises: the weight today
  RepRange get range => RepRange(lo, hi);
  double relative = 1; // today's work against the user's usual (the working level): 0.6 lighter, 1 usual, 1.1 the next level
  bool nextLevel = false; // a hard day: every set at the next level. Reach the floor on every working set and it is yours today.
  double? usualLoadKg; // loaded exercises: the weight at the user's level in today's reps, so a set can be read by its worth
  double secPerSet;
  List<SetLog> sets;
  List<Warmup> warmups;
  bool edited;
  bool lightened;     // one rung down after a week away

  Exercise get exercise => exerciseById[exId]!;
  Iterable<SetLog> get attempted => sets.where((s) => s.attempted);
  int get total => attempted.fold(0, (a, s) => a + s.reps!);
  bool get done => sets.every((s) => s.attempted);

  /// True when today asked for the working level: the user's level and at least the working sets.
  bool get atWorkingLevel => intent != 'light' && !lightened && sets.length >= workingSets;

  Map<String, dynamic> toJson() => {
        'slot': slot, 'exId': exId, 'muscle': muscle, 'intent': intent, 'workingSets': workingSets, 'rung': rung, 'rungLabel': rungLabel, 'target': target, 'lo': lo, 'hi': hi,
        'atCeiling': atCeiling, 'bestTotal': bestTotal, 'difficulty': difficulty, 'loadKg': loadKg, 'relative': relative,
        'nextLevel': nextLevel, 'usualLoadKg': usualLoadKg, 'secPerSet': secPerSet, 'sets': sets.map((s) => s.toJson()).toList(),
        'warmups': warmups.map((w) => w.toJson()).toList(), 'edited': edited, 'lightened': lightened,
        'why': why, 'fresh': fresh, 'asked': asked,
      };
  static SessionExercise fromJson(Map<String, dynamic> j) => SessionExercise(
        slot: j['slot'], exId: exerciseRenames[j['exId']] ?? j['exId'], muscle: j['muscle'] ?? _groupOf(j['exId']), intent: j['intent'] ?? 'working', workingSets: j['workingSets'] ?? (j['sets'] as List).length,
        why: j['why'] ?? '', fresh: j['fresh'] ?? false, asked: j['asked'] ?? false,
        rung: j['rung'], rungLabel: j['rungLabel'], target: j['target'],
        lo: j['lo'], hi: j['hi'], atCeiling: j['atCeiling'] ?? false, bestTotal: j['bestTotal'] ?? 0,
        difficulty: j['difficulty'] ?? foldDifficulty(j['cost'] ?? 3),
        loadKg: (j['loadKg'] as num?)?.toDouble(), secPerSet: (j['secPerSet'] as num).toDouble(),
        sets: (j['sets'] as List).map((s) => SetLog.fromJson(s)).toList(),
        warmups: ((j['warmups'] ?? []) as List).map((w) => Warmup.fromJson(w)).toList(), edited: j['edited'] ?? false, lightened: j['lightened'] ?? false,
      )..relative = (j['relative'] as num?)?.toDouble() ?? 1
        ..nextLevel = j['nextLevel'] ?? false
        ..usualLoadKg = (j['usualLoadKg'] as num?)?.toDouble();
}

/// The muscle an exercise is filed under: its first primary muscle. For older sessions that carried no muscle.
String _groupOf(String exId) {
  final ex = exerciseById[exId];
  return ex == null || ex.primary.isEmpty ? 'other' : ex.primary.first;
}

/// How often as saved: per muscle, or per group before selection ran on muscles, when a group's word spreads to each
/// of its muscles. A muscle's own word wins over its group's.
Map<String, int> _oftenFrom(Map j) {
  final out = <String, int>{};
  for (final e in j.entries) {
    final v = (e.value as int).clamp(-1, 1);
    if (v == 0 || !muscleGroups.contains(e.key)) continue;
    for (final m in musclesOfGroup(e.key as String)) { out[m] = v; }
  }
  for (final e in j.entries) {
    final v = (e.value as int).clamp(-1, 1);
    if (trackedMuscles.contains(e.key)) { if (v == 0) { out.remove(e.key); } else { out[e.key as String] = v; } }
  }
  return out;
}

class Session {
  Session({
    required this.id, required this.type, required this.name, this.itemIndex = 0, required this.locationId,
    required this.energy, required this.timeMinutes, required this.energyChosen, required this.timeChosen, required this.stateAtStart,
    this.kind, this.exercises = const [], this.minutes, this.routine, this.cardio, this.estMinutes = 0, this.cardioMinutes = 0, this.stretchMinutes = 0,
    this.spareMinutes = 0, this.circuit = false, this.warmupMinutes = 0,
  });
  String id;
  String type;           // lift | move
  String? kind;          // cardio | mobility
  String name;
  int itemIndex;
  String? locationId;
  Energy energy;
  int timeMinutes;       // the minutes the user said they had
  bool energyChosen;     // the user changed it from the default
  bool timeChosen;
  PersonState stateAtStart;
  List<SessionExercise> exercises;
  int? minutes;          // cardio duration
  String? routine;       // mobility
  String? cardio;
  int? effort;           // cardio perceived effort 1 to 3
  int estMinutes;
  int cardioMinutes;     // the cardio block at the end: the share, plus any slack the lifting left
  int stretchMinutes;    // the stretching block, last
  int spareMinutes;      // minutes left as rest when spare minutes are for rest
  double relative = 1;   // the whole workout against the user's usual: below 1 lighter, 1 usual, above 1 more
  int pushes = 0;        // exercises trained at the next level today
  bool circuit;          // one set of each exercise per round, instead of all sets of one exercise
  int warmupMinutes;     // the warm-up block before the lifting
  /// When each item of the workout started (warm-up, each exercise or the circuit, cardio, stretching), by its key. An
  /// item runs until the next one starts, so its time includes the rest inside it. The latest is the current item.
  Map<String, DateTime> itemStarts = {};
  List<int> skipped = [];
  DateTime? startedAt;
  DateTime? endedAt;
  StopReason? stopReason;
  int? stopAt;           // exercise index where the stop happened
  Feel? feel;
  String note = '';      // the one line to the human
  bool swappedToMove = false;
  int? calendarEventId;  // the event auto-track wrote, so the calendar read can tell it from busy time
  List<String> uncovered = [];  // forced muscles no exercise could cover today, or a swap uncovered; never saved
  List<String> requirements = []; // preview requirements, retained across exercise draws and swaps; never saved

  int? get elapsedMinutes => startedAt == null || endedAt == null ? null : endedAt!.difference(startedAt!).inMinutes;

  Map<String, dynamic> toJson() => {
        'id': id, 'type': type, 'kind': kind, 'name': name, 'itemIndex': itemIndex, 'locationId': locationId, 'energy': _e(energy), 'timeMinutes': timeMinutes,
        'energyChosen': energyChosen, 'timeChosen': timeChosen, 'stateAtStart': _e(stateAtStart), 'exercises': exercises.map((e) => e.toJson()).toList(),
        'minutes': minutes, 'routine': routine, 'cardio': cardio, 'effort': effort, 'estMinutes': estMinutes, 'cardioMinutes': cardioMinutes,
        'stretchMinutes': stretchMinutes, 'spareMinutes': spareMinutes, 'relative': relative, 'pushes': pushes,
        'startedAt': _ms(startedAt), 'endedAt': _ms(endedAt), 'stopReason': stopReason == null ? null : _e(stopReason!), 'stopAt': stopAt,
        'feel': feel == null ? null : _e(feel!), 'note': note, 'swappedToMove': swappedToMove, 'circuit': circuit, 'skipped': skipped,
        'calendarEventId': calendarEventId, 'warmupMinutes': warmupMinutes, 'items': itemStarts.map((k, v) => MapEntry(k, _ms(v))),
      };
  static Session fromJson(Map<String, dynamic> j) => Session(
        id: j['id'], type: j['type'], kind: j['kind'], name: j['name'], itemIndex: j['itemIndex'] ?? 0, locationId: j['locationId'],
        energy: _p(Energy.values, j['energy'], Energy.normal),
        timeMinutes: j['timeMinutes'] ?? const {'short': 20, 'normal': 35, 'long': 50}[j['time']] ?? minutesDefault,
        energyChosen: j['energyChosen'] ?? false, timeChosen: j['timeChosen'] ?? false, stateAtStart: _p(PersonState.values, j['stateAtStart'], PersonState.active),
        exercises: ((j['exercises'] ?? []) as List).map((e) => SessionExercise.fromJson(e)).toList(),
        minutes: j['minutes'], routine: j['routine'], cardio: j['cardio'], estMinutes: j['estMinutes'] ?? 0, cardioMinutes: j['cardioMinutes'] ?? j['bonusCardioMinutes'] ?? 0, stretchMinutes: j['stretchMinutes'] ?? 0,
        spareMinutes: j['spareMinutes'] ?? 0,
        circuit: j['circuit'] ?? false, warmupMinutes: j['warmupMinutes'] ?? 0,
      )
      ..itemStarts = (j['items'] as Map? ?? {}).map((k, v) => MapEntry(k as String, _d(v)!))
      ..relative = (j['relative'] as num?)?.toDouble() ?? 1
      ..pushes = j['pushes'] ?? 0
    ..skipped = List<int>.from(j['skipped'] ?? [])
    ..effort = j['effort']
    ..startedAt = _d(j['startedAt'])
    ..endedAt = _d(j['endedAt'])
    ..stopReason = j['stopReason'] == null ? null : _p(StopReason.values, j['stopReason'], StopReason.time)
    ..stopAt = j['stopAt']
    ..feel = j['feel'] == null ? null : _p(Feel.values, j['feel'], Feel.right)
    ..note = j['note'] ?? ''
    ..swappedToMove = j['swappedToMove'] ?? false
    ..calendarEventId = j['calendarEventId'];
}

/// What carries over between workouts that is not a level: pain pauses, the two defaults, and the muscles the user asked
/// for by hand. There is no rotation: every workout is built from history when the user shows up (SELECTION.md).
class Plan {
  Plan();
  Map<String, DateTime> paused = {};     // exercise id -> until: the exercise and its primary muscles rest
  Energy energyDefault = Energy.normal;
  int timeDefault = minutesDefault;
  DateTime? continuedOn;  // the day the user chose to start another workout after finishing one
  List<({String muscle, DateTime at})> asked = [];  // muscles asked for by hand, for the one line suggesting more emphasis
  List<String> moreSuggested = [];                  // muscles that line has been said for
  Map<String, dynamic> toJson() => {
        'paused': paused.map((k, v) => MapEntry(k, _ms(v))), 'energyDefault': _e(energyDefault), 'timeDefault': timeDefault, 'continuedOn': _ms(continuedOn),
        'asked': [for (final a in asked) {'g': a.muscle, 'at': _ms(a.at)}], 'moreSuggested': moreSuggested,
      };
  static Plan fromJson(Map<String, dynamic> j) => Plan()
    ..paused = ((j['paused'] as Map? ?? {}).map((k, v) => MapEntry(k as String, _d(v)!))..removeWhere((k, _) => !exerciseById.containsKey(k)))
    ..energyDefault = _p(Energy.values, j['energyDefault'], Energy.normal)
    ..timeDefault = j['timeDefault'] is int ? j['timeDefault'] : minutesDefault
    ..continuedOn = _d(j['continuedOn'])
    // entries from before selection ran on muscles named groups: they are dropped, the window is two weeks anyway
    ..asked = [for (final a in (j['asked'] as List? ?? [])) if (trackedMuscles.contains(a['g'])) (muscle: a['g'] as String, at: _d(a['at'])!)]
    ..moreSuggested = [for (final m in List<String>.from(j['moreSuggested'] ?? [])) if (trackedMuscles.contains(m)) m];
}

class Person {
  String? nudgedFor;      // "<lastSessionId>:<state>" so one nudge per transition
  bool nudgeDismissed = false;
  Map<String, dynamic> toJson() => {'nudgedFor': nudgedFor, 'nudgeDismissed': nudgeDismissed};
  static Person fromJson(Map<String, dynamic> j) => Person()
    ..nudgedFor = j['nudgedFor']
    ..nudgeDismissed = j['nudgeDismissed'] ?? false;
}

class AppState {
  int version = 6;
  Profile? profile;
  GoalConfig? goal;
  List<Location> locations = [];
  String? lastLocationId;
  String units = 'kg';
  Settings settings = Settings();
  Plan? plan;
  Map<String, ExerciseState> ex = {};
  Person person = Person();
  List<Session> sessions = [];   // completed, oldest first
  Session? active;
  int clockOffsetDays = 0;       // prototype clock shift
  bool dev = false;
  int seq = 0;                   // id counter
  bool seenHow = false;          // the "how it works" page was shown

  String nextId(String prefix) => '$prefix${++seq}';

  Map<String, dynamic> toJson() => {
        'version': version, 'profile': profile?.toJson(), 'goal': goal?.toJson(), 'locations': locations.map((l) => l.toJson()).toList(), 'lastLocationId': lastLocationId,
        'units': units, 'settings': settings.toJson(), 'plan': plan?.toJson(), 'ex': ex.map((k, v) => MapEntry(k, v.toJson())), 'person': person.toJson(),
        'sessions': sessions.map((s) => s.toJson()).toList(), 'active': active?.toJson(), 'clockOffsetDays': clockOffsetDays, 'dev': dev, 'seq': seq, 'seenHow': seenHow,
      };
  static AppState fromJson(Map<String, dynamic> j) {
    final s = AppState()
      ..profile = j['profile'] == null ? null : Profile.fromJson(j['profile'])
      ..goal = j['goal'] == null ? null : GoalConfig.fromJson(j['goal'])
      ..locations = ((j['locations'] ?? []) as List).map((l) => Location.fromJson(l)).toList()
      ..lastLocationId = j['lastLocationId']
      ..units = j['units'] ?? 'kg'
      ..settings = Settings.fromJson(j['settings'] ?? {})
      ..plan = j['plan'] == null ? null : Plan.fromJson(j['plan'])
      ..ex = (j['ex'] as Map? ?? {}).map((k, v) => MapEntry(k as String, ExerciseState.fromJson(v)))
      ..version = 6
      ..person = Person.fromJson(j['person'] ?? {})
      ..sessions = ((j['sessions'] ?? []) as List).map((x) => Session.fromJson(x)).toList()
      ..active = j['active'] == null ? null : Session.fromJson(j['active'])
      ..clockOffsetDays = j['clockOffsetDays'] ?? 0
      ..dev = j['dev'] ?? false
      ..seq = j['seq'] ?? 0
      ..seenHow = j['seenHow'] ?? false;
    // older builds kept the goal id on the profile
    if (s.goal == null && j['profile']?['goal'] != null) s.goal = GoalConfig.fromTemplate(goals[j['profile']['goal']] ?? goals.values.first);
    // older builds named workouts "Day A"
    for (final x in s.sessions) { if (x.name.startsWith('Day ')) x.name = 'Workout ${x.name.substring(4)}'; }
    // merged exercises: progress follows the id that replaced them
    for (final r in exerciseRenames.entries) {
      final st = s.ex.remove(r.key);
      if (st != null) s.ex.putIfAbsent(r.value, () => st);
    }
    s.ex.removeWhere((k, _) => !exerciseById.containsKey(k));
    if ((j['version'] ?? 1) < 4) _migrateMaxes(s, j);
    if ((j['version'] ?? 1) < 5) _migrateLibrary(s);
    if ((j['version'] ?? 1) < 6) _migrateBenchRacks(s);
    return s;
  }

  Location? location(String? id) {
    if (locations.isEmpty) return null;
    return locations.firstWhere((l) => l.id == id, orElse: () => locations.firstWhere((l) => l.id == lastLocationId, orElse: () => locations.first));
  }

  Session? get lastSession => sessions.isEmpty ? null : sessions.last;
}

/// Version 5 brought the reviewed exercise library (docs/app/EXERCISE_DATA.md). Ladders whose versions moved keep each
/// saved level on the same version by name, in progress and in history; locations get the new gear they already have
/// (a gym has everything; a barbell comes with plates).
void _migrateLibrary(AppState s) {
  // the assisted machine's level was kept as assistance, which ran backwards; it starts again from experience
  s.ex.remove('assisted_pullup');
  for (final id in rungHistory.keys) {
    final st = s.ex[id];
    if (st != null) {
      st.rung = remapRung(id, st.rung);
      st.startRung = remapRung(id, st.startRung);
    }
  }
  for (final x in [...s.sessions, if (s.active != null) s.active!]) {
    for (final e in x.exercises) {
      if (rungHistory.containsKey(e.exId)) e.rung = remapRung(e.exId, e.rung);
    }
  }
  const added = ['weight_plate', 'bench_decline', 'preacher_bench', 'sled', 'gym_rings', 'wrist_roller'];
  for (final l in s.locations) {
    if (l.template == 'gym') {
      for (final g in added) { if (!l.equipment.contains(g)) l.equipment.add(g); }
    } else if (l.equipment.contains('barbell') && !l.equipment.contains('weight_plate')) {
      l.equipment.add('weight_plate');
    }
  }
}

/// Version 6 added benches with the rack built in, a second way to do the barbell bench presses. A gym has them.
void _migrateBenchRacks(AppState s) {
  const added = ['bench_flat_rack', 'bench_incline_rack', 'bench_decline_rack'];
  for (final l in s.locations) {
    if (l.template != 'gym') continue;
    for (final g in added) { if (!l.equipment.contains(g)) l.equipment.add(g); }
  }
}

/// Before version 4 a loaded exercise's base was its working weight; now it is an estimated max. Lift it by the share the
/// old goal trained at, so the weights the user sees do not change.
void _migrateMaxes(AppState s, Map<String, dynamic> j) {
  final tpl = (j['goal'] as Map?)?['template'];
  final pct = tpl == 'strength' ? 0.85 : (tpl == 'fit' || tpl == 'feel') ? 0.60 : 0.70;
  for (final st in s.ex.values) {
    if (st.baseKg != null) st.baseKg = st.baseKg! / pct;
  }
}
