// Settings: the goal and units, locations and position, exercises, the reminder, the calendar, the progression
// settings, breaks, updates, feedback, your data (copy and restore), and (staging only) prototype tools.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/index.dart';
import '../data/library.dart';
import '../data/model.dart';
import '../data/store.dart';
import '../features.dart';
import '../integrations.dart';
import '../logic/after.dart';
import '../logic/builder.dart';
import '../logic/rotation.dart';
import 'app.dart';
import 'catalog.dart';
import 'feedback.dart';
import 'goal_editor.dart';
import 'how.dart';
import 'location_editor.dart';
import 'motion.dart';
import 'muscle_figure.dart';
import 'theme.dart';
import 'updates.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool syncing = false;
  Position2? here;          // after a refresh: distances to every saved place
  bool locating = false;
  final _updates = GlobalKey();   // the Updates section, which the update banner scrolls to

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted && context.store.state.settings.calendar) _sync(); });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.state;
    final st = s.settings;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    const counts = {1: '1', 2: '2', 3: '3', 4: '4', 5: '5'};
    final g = s.goal!;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), actions: [
        TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HowItWorks())), icon: const Icon(LucideIcons.circleHelp, size: 18), label: const Text('How it works')),
      ]),
      // Not a lazy ListView: the banner scrolls to the Updates section, which has to be built to be found.
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        UpdateBanner(onGo: _goToUpdate),
        const SectionHeader('Goal', icon: LucideIcons.target),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconBadge(goalIcon(g.template), accent: true),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.name, style: t.titleMedium),
              Text('${g.program == null ? 'your own reps' : '${programLabel[g.program]!} reps'} · hard exercises ${g.rowFor(3).map(rangeText).join(', then ')} · spare minutes: ${spareLabel[g.spare]!.toLowerCase()}', style: t.bodySmall),
              Text('${g.exercises.min} to ${g.exercises.max} exercises, ideally ${g.exercises.ideal} · ${g.sets.ideal} working sets · ${g.moveEvery == 0 ? 'no movement days' : 'a movement day after every ${g.moveEvery} workouts'}', style: t.bodySmall),
            ])),
            IconButton.outlined(onPressed: () => _editGoal(context), icon: const Icon(LucideIcons.pencil, size: 18), tooltip: 'Change the goal'),
          ]),
          const Divider(height: 24),
          ChoiceRow<int>(label: 'Days a week', value: s.profile!.daysPerWeek, options: const {1: '1', 2: '2', 3: '3', 4: '4', 5: '5', 6: '6'}, onChanged: (v) => store.update((x) { x.profile!.daysPerWeek = v; rebuildRotation(x); })),
          Text('Your rotation', style: t.labelMedium),
          const SizedBox(height: 6),
          RotationPreview(s.plan!.rotation, current: s.plan!.index),
          const SizedBox(height: 14),
          Text('Units', style: t.labelMedium),
          const SizedBox(height: 6),
          Segmented<String>(value: s.units, options: const {'kg': 'Kilograms', 'lb': 'Pounds'}, icons: const {'kg': LucideIcons.weight, 'lb': LucideIcons.scale}, onChanged: (v) => store.update((x) => x.units = v)),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Personalization', icon: LucideIcons.userRound),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Body figure', style: t.labelMedium),
          Text('The figure that shows which muscles a workout works, on Today and in Progress.', style: t.bodySmall),
          const SizedBox(height: 10),
          Row(children: [
            for (final f in const ['male', 'female']) ...[
              if (f != 'male') const SizedBox(width: 12),
              Expanded(child: _FigureChoice(figure: f, selected: st.figure == f, onTap: () => store.update((_) => st.figure = f))),
            ],
          ]),
        ])),
        const SizedBox(height: 20),
        SectionHeader('Locations', icon: LucideIcons.mapPin, trailing: st.location
            ? TextButton.icon(onPressed: locating ? null : _refreshDistances, icon: Icon(locating ? LucideIcons.loader : LucideIcons.refreshCw, size: 14), label: Text(here == null ? 'Distances' : 'Refresh'), style: TextButton.styleFrom(visualDensity: VisualDensity.compact))
            : null),
        Panel(padding: EdgeInsets.zero, child: Column(children: [
          for (final l in s.locations)
            ListTile(
              leading: IconBadge(locationIcon(l.template), size: 36), title: Text(l.name),
              subtitle: Text('${l.equipment.isEmpty ? 'bodyweight only' : '${l.equipment.length} items'} · ${l.hasPosition ? (here != null ? LocationBridge.distanceText(LocationBridge.distance(l, here!)!) : 'position saved') : 'anywhere'}'),
              trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary), onTap: () => _editLocation(context, l),
            ),
          ListTile(leading: const IconBadge(LucideIcons.plus, size: 36), title: const Text('Add a location'), onTap: () => _addLocation(context)),
          const Divider(height: 8),
          SwitchListTile(
            secondary: const IconBadge(LucideIcons.locate, size: 36),
            title: const Text('Position'), subtitle: Text(st.location ? 'Read once when the app opens and when you ask. Picks the nearest saved place within ${LocationBridge.nearbyMetres.round()} m.' : 'Picks the nearest saved place for you. Read once when the app opens, never in the background. Save a position on each location to use it.'),
            value: st.location, onChanged: (v) => _toggleLocation(context, v),
          ),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Exercises', icon: LucideIcons.layers),
        Panel(padding: EdgeInsets.zero, child: Column(children: [
          ListTile(leading: const IconBadge(LucideIcons.layers, size: 36), title: const Text('Group by'), subtitle: Text('${indexLabel[st.index]}. ${indexBlurb[st.index]}'), trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
              onTap: () => pickIndex(context)),
          ListTile(leading: const IconBadge(LucideIcons.bookOpen, size: 36), title: Text('${exercises.length} exercises'), subtitle: const Text('Built in. Loaded ones by weight, bodyweight ones by version.'), trailing: Icon(LucideIcons.chevronRight, size: 18, color: du.inkTertiary),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CatalogScreen()))),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Reminder', icon: LucideIcons.bell),
        Panel(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(children: [
          SwitchListTile(
            secondary: const IconBadge(LucideIcons.sunrise, size: 36),
            title: const Text('One a day'), subtitle: Text(st.notify ? 'At ${_hour(st.notifyHour)}. The same calm line every time, never more.' : 'One notification a day, at an hour you pick. Nothing else, ever.'),
            value: st.notify, onChanged: (v) => _toggleNotify(context, v),
          ),
          if (st.notify) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Column(children: [
            ValueSlider(label: 'At', value: st.notifyHour, min: 5, max: 22, display: _hour, icon: LucideIcons.clock, onChanged: (v) { store.update((_) => st.notifyHour = v); Notifications.scheduleDaily(v); }),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => Notifications.showNow('Your workout is ready', 'Two questions and a start button. Easy counts.'), icon: const Icon(LucideIcons.play, size: 16), label: const Text('Send a test'))),
          ])),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Calendar', icon: LucideIcons.calendarDays),
        Panel(padding: const EdgeInsets.symmetric(vertical: 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            secondary: const IconBadge(LucideIcons.calendarDays, size: 36),
            title: const Text('Read my day'), subtitle: Text(st.calendar ? 'Reads today\'s events when the app opens and when you ask. Never in the background, never sent anywhere.' : 'A busy day makes a lighter default, and a free slot is suggested. Reads only today, only when the app is open.'),
            value: st.calendar, onChanged: (v) => _toggleCalendar(context, v),
          ),
          if (st.calendar) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _todayReadout(context),
            const Divider(height: 20),
            RangeBand(
              label: 'Awake hours', value: RepRange(st.awakeStart ~/ 60, st.awakeEnd ~/ 60), min: 0, max: 24, unit: '',
              hint: 'The hours you count as your day. Every calendar calculation happens inside them.',
              onChanged: (v) { final end = v.hi < v.lo + 6 ? v.lo + 6 : v.hi; store.update((_) { st.awakeStart = v.lo * 60; st.awakeEnd = end.clamp(0, 24) * 60; }); _reshape(); },
            ),
            const Divider(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('A busy day makes a lighter day'), subtitle: const Text('Sets the two daily defaults; one tap overrides them, and a default is never your choice.'),
              value: st.busyAdjust, onChanged: (v) => store.update((_) => st.busyAdjust = v),
            ),
            if (st.busyAdjust) ...[
              ValueSlider(label: 'Busy share that shortens the default to $busyDayMinutes minutes', value: st.busyShort, min: 30, max: 90, step: 5, unit: ' %', icon: LucideIcons.clock,
                  onChanged: (v) => store.update((_) { st.busyShort = v; if (st.busyEasy < v) st.busyEasy = v; })),
              ValueSlider(label: 'Busy share that also makes the default easy', value: st.busyEasy, min: st.busyShort, max: 100, step: 5, unit: ' %', icon: LucideIcons.batteryLow,
                  onChanged: (v) => store.update((_) => st.busyEasy = v)),
            ],
            const Divider(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-track'), subtitle: Text(st.autoTrack ? 'Every finished workout is written from start to end, with what actually happened.' : 'Write finished workouts to the calendar, start to end, with what actually happened. Nothing for a workout that never started.'),
              value: st.autoTrack, onChanged: (v) => _toggleAutoTrack(context, v),
            ),
            if (st.autoTrack)
              ChoiceRow<String?>(
                label: 'Calendar to write to',
                value: CalendarSync.calendars.any((c) => c.id == st.calendarId) ? st.calendarId : null,
                options: {null: 'Primary', for (final c in CalendarSync.calendars) c.id: c.name.isEmpty ? c.account : c.name},
                hint: CalendarSync.calendars.isEmpty ? 'No writable calendars found yet. Tap sync to look again.' : null,
                onChanged: (v) => store.update((_) => st.calendarId = v),
              ),
            const SizedBox(height: 4),
            Text('Planning a slot ahead of time, with a declinable event, is not built yet.', style: t.bodySmall),
          ])),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Workout', icon: LucideIcons.timer),
        const Explain('Lifting is a set, from I\'m ready until your reps are in. Rest is everything between sets: catching your breath, moving to the next exercise and setting it up.'),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChoiceRow<bool>(label: 'When the planned rest runs out', value: st.restAuto, options: const {false: 'Keep resting', true: 'Start the next set'},
              hint: st.restAuto ? 'The planned rest is a timer: when it ends, the next set or round starts as if you had tapped I\'m ready.' : 'Rest counts up for as long as you like. The planned time is only a guide.',
              onChanged: (v) => store.update((_) => st.restAuto = v)),
          ChoiceRow<bool>(label: 'Show lifting and rest as', value: st.timeAsShare, options: const {false: 'Minutes', true: 'Share of time'},
              onChanged: (v) => store.update((_) => st.timeAsShare = v)),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Progressions', icon: LucideIcons.listOrdered),
        const Explain(progressionExplainer),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChoiceRow<int>(label: 'Workouts at the top before a level goes up', value: st.stepUp, options: counts, icons: const {1: LucideIcons.zap}, onChanged: (v) => store.update((_) => st.stepUp = v)),
          ChoiceRow<int>(label: 'Workouts below the bottom before a level comes down', value: st.stepDown, options: counts, onChanged: (v) => store.update((_) => st.stepDown = v)),
          ChoiceRow<int>(label: 'Weeks before an unused level eases down', value: st.decayWeeks, options: const {0: 'off', 2: '2', 3: '3', 4: '4', 5: '5', 6: '6', 7: '7', 8: '8'},
              hint: 'One level per period, never below where it started. One good workout climbs straight back.', onChanged: (v) => store.update((_) => st.decayWeeks = v)),
        ])),
        const SizedBox(height: 20),
        const SectionHeader('Breaks', icon: LucideIcons.bedDouble),
        Panel(child: Column(children: [
          ValueSlider(label: 'Days away before easy is the default', value: st.daysAway, min: 5, max: 21, unit: ' days', icon: LucideIcons.sunrise, onChanged: (v) => store.update((_) => st.daysAway = v)),
          const Divider(height: 20),
          ValueSlider(label: 'Days an exercise rests after pain', value: st.painRestDays, min: 3, max: 28, unit: ' days', icon: LucideIcons.bandage, onChanged: (v) => store.update((_) => st.painRestDays = v)),
        ])),
        const SizedBox(height: 20),
        ValueListenableBuilder(valueListenable: updateAvailable, builder: (_, r, _) =>
            SectionHeader('Updates', key: _updates, icon: LucideIcons.download, marker: r == null ? null : const UpdateDot())),
        const UpdatePanel(),
        const SizedBox(height: 20),
        const SectionHeader('Feedback', icon: LucideIcons.messageSquareText),
        const FeedbackPanel(),
        const SizedBox(height: 20),
        const SectionHeader('Your data', icon: LucideIcons.hardDrive),
        Panel(padding: EdgeInsets.zero, child: Column(children: [
          ListTile(leading: const IconBadge(LucideIcons.copy, size: 36), title: const Text('Copy your data'),
              subtitle: const Text('Profile, locations, levels and history, as text. Paste it into another install to move everything there.'), onTap: () => _copyData(context)),
          ListTile(leading: const IconBadge(LucideIcons.clipboardPaste, size: 36), title: const Text('Restore copied data'),
              subtitle: const Text('Replaces everything on this phone with data copied from this app.'), onTap: () => _restoreData(context)),
        ])),
        if (prototypeTools) ...[
          const SizedBox(height: 20),
          const SectionHeader('Prototype tools', icon: LucideIcons.wrench),
          Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(LucideIcons.clock, size: 16, color: du.inkSecondary), const SizedBox(width: 8),
              Expanded(child: Text('Clock: ${s.clockOffsetDays == 0 ? 'real time' : '${s.clockOffsetDays > 0 ? '+' : ''}${s.clockOffsetDays} days'} · today ${_date(store.now)}', style: t.bodyMedium)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => store.update((x) => x.clockOffsetDays += 1), child: const Text('+1 day')),
              OutlinedButton(onPressed: () => store.update((x) => x.clockOffsetDays += 7), child: const Text('+7 days')),
              OutlinedButton(onPressed: () => store.update((x) => x.clockOffsetDays += 28), child: const Text('+4 weeks')),
              OutlinedButton.icon(onPressed: () => store.update((x) => x.clockOffsetDays = 0), icon: const Icon(LucideIcons.rotateCcw, size: 16), label: const Text('Reset clock')),
            ]),
            const SizedBox(height: 14),
            Text('Simulate a workout with every set at the top, then move the clock on two days.', style: t.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: () => _simulate(context, Energy.normal), child: const Text('Clean normal workout')),
              OutlinedButton(onPressed: () => _simulate(context, Energy.hard), child: const Text('Clean hard workout')),
              OutlinedButton(onPressed: () => _simulate(context, Energy.normal, shortReps: true), child: const Text('Short workout')),
            ]),
            const SizedBox(height: 14),
            TextButton.icon(onPressed: () => _confirmReset(context), style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), icon: const Icon(LucideIcons.trash2, size: 16), label: const Text('Erase everything')),
            Text('${exercises.length} exercises built in', style: t.labelSmall?.copyWith(color: du.inkTertiary)),
          ])),
        ],
      ])),
    );
  }

  void _goToUpdate() {
    final c = _updates.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: m(context, durSlow), curve: easeInOut, alignment: 0.1);
  }

  /// A plain readout of today as the app sees it: free, busy and workout minutes, with "last synced" and sync now.
  Widget _todayReadout(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final d = CalendarSync.day;
    return Row(children: [
      Expanded(child: d == null
          ? Text(syncing ? 'Reading today…' : 'Today not read yet.', style: t.bodySmall)
          : Row(children: [
              StatTile(label: 'free', value: _hm(d.free), icon: LucideIcons.coffee),
              const SizedBox(width: 18),
              StatTile(label: 'busy', value: _hm(d.busy), icon: LucideIcons.briefcase, hint: '${d.busyPct} %'),
              const SizedBox(width: 18),
              StatTile(label: 'workout', value: _hm(d.workout), icon: LucideIcons.dumbbell),
            ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        TextButton.icon(onPressed: syncing ? null : _sync, icon: Icon(syncing ? LucideIcons.loader : LucideIcons.refreshCw, size: 14), label: const Text('Sync now'), style: TextButton.styleFrom(visualDensity: VisualDensity.compact)),
        Text(CalendarSync.agoText(DateTime.now()), style: t.labelSmall?.copyWith(color: du.inkTertiary)),
      ]),
    ]);
  }

  String _hm(int m) => m >= 60 ? '${m ~/ 60} h ${m % 60 == 0 ? '' : '${m % 60} min'}'.trim() : '$m min';
  String _hour(int h) => '${h.toString().padLeft(2, '0')}:00';
  String _date(DateTime d) => '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';

  void _say(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _sync() async {
    final store = context.store;
    setState(() => syncing = true);
    await CalendarSync.sync(store.state, store.now);
    await CalendarSync.loadCalendars();
    if (mounted) setState(() => syncing = false);
  }

  /// The awake window changed: reshape the day from the events already read, without another read.
  void _reshape() => _sync();

  Future<void> _refreshDistances() async {
    setState(() => locating = true);
    final p = await LocationBridge.current();
    if (!mounted) return;
    setState(() { locating = false; here = p; });
    if (p == null) _say(context, 'Could not read the position. Try again outdoors or with location on.');
  }

  Future<void> _toggleNotify(BuildContext context, bool on) async {
    final store = context.store;
    if (!on) { store.update((x) => x.settings.notify = false); await Notifications.cancel(); return; }
    final ok = await Notifications.requestPermission();
    if (!context.mounted) return;
    if (!ok) { _say(context, 'Notifications are off for this app in Android settings.'); return; }
    store.update((x) => x.settings.notify = true);
    await Notifications.scheduleDaily(store.state.settings.notifyHour);
  }

  Future<void> _toggleCalendar(BuildContext context, bool on) async {
    final store = context.store;
    if (!on) { store.update((x) => x.settings.calendar = false); CalendarSync.day = null; setState(() {}); return; }
    final ok = await CalendarBridge.requestPermission();
    if (!context.mounted) return;
    if (!ok) { _say(context, 'Calendar access was not granted.'); return; }
    store.update((x) => x.settings.calendar = true);
    await _sync();
  }

  Future<void> _toggleAutoTrack(BuildContext context, bool on) async {
    final store = context.store;
    if (!on) { store.update((x) => x.settings.autoTrack = false); return; }
    final ok = await CalendarBridge.requestWritePermission();
    if (!context.mounted) return;
    if (!ok) { _say(context, 'Calendar write access was not granted.'); return; }
    store.update((x) => x.settings.autoTrack = true);
    await CalendarSync.loadCalendars();
    if (mounted) setState(() {});
  }

  Future<void> _toggleLocation(BuildContext context, bool on) async {
    final store = context.store;
    if (!on) { store.update((x) => x.settings.location = false); setState(() => here = null); return; }
    final ok = await LocationBridge.requestPermission();
    if (!context.mounted) return;
    if (!ok) { _say(context, 'Location access was not granted.'); return; }
    store.update((x) => x.settings.location = true);
  }

  Future<void> _editGoal(BuildContext context) async {
    final store = context.store;
    await showSheet<void>(context, SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 24), children: [
        const SheetHeader('Goal', subtitle: 'Your own, in plain words. Levels stay where they are.', icon: LucideIcons.target),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GoalEditor(goal: store.state.goal!, daysPerWeek: store.state.profile!.daysPerWeek, onChanged: (_) => store.update((x) => rebuildRotation(x))),
        ),
      ]),
    ));
  }

  void _simulate(BuildContext context, Energy energy, {bool shortReps = false}) {
    final store = context.store;
    store.update((s) {
      var now = store.now;
      while (s.plan!.rotation[s.plan!.index].type != 'lift') { s.plan!.index = (s.plan!.index + 1) % s.plan!.rotation.length; }
      final session = buildSession(s, BuildOptions(energy: energy, minutes: s.plan!.timeDefault, locationId: s.lastLocationId), now);
      startSession(s, session, now);
      for (var i = 0; i < session.exercises.length; i++) {
        final e = session.exercises[i];
        for (var k = 0; k < e.sets.length; k++) {
          now = now.add(Duration(seconds: e.secPerSet.round()));
          logSet(session, i, shortReps ? (e.lo - 1).clamp(0, e.target) : e.target, now);
        }
      }
      finishSession(s, session, Finish(feel: Feel.right), now);
      s.clockOffsetDays += 2;
    });
    _say(context, store.state.sessions.last.note);
  }

  Future<void> _copyData(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: context.store.exportJson()));
    if (context.mounted) _say(context, 'Copied. Open the other install and restore it there.');
  }

  /// Restores a copy, then turns back on, one permission ask at a time, whatever the copy had on.
  Future<void> _restoreData(BuildContext context) async {
    final want = await restoreCopiedData(context);
    if (want == null || !context.mounted) return;
    _say(context, 'Restored.');
    if (want.notify) await _toggleNotify(context, true);
    if (want.calendar && context.mounted) await _toggleCalendar(context, true);
    if (want.autoTrack && context.mounted) await _toggleAutoTrack(context, true);
    if (want.location && context.mounted) await _toggleLocation(context, true);
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Erase everything?'),
      content: const Text('Profile, locations, levels and history. There is no undo.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Erase'))],
    ));
    if (ok == true && context.mounted) context.store.reset();
  }

  Future<void> _addLocation(BuildContext context) async {
    final store = context.store;
    late Location l;
    store.update((s) => s.locations.add(l = Location(id: s.nextId('l'), name: 'My place', equipment: [])));
    if (context.mounted) await _editLocation(context, l, isNew: true);
  }

  Future<void> _editLocation(BuildContext context, Location l, {bool isNew = false}) async {
    final store = context.store;
    await showSheet<void>(context, SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: ListView(padding: const EdgeInsets.fromLTRB(0, 0, 0, 24), children: [
        SheetHeader(isNew ? 'New location' : 'Location', subtitle: 'Name it, place it, tick what is there. Levels belong to the exercise, not the place.', icon: locationIcon(l.template)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LocationEditor(location: l, onChanged: () => store.update((_) {}), say: (m) { if (context.mounted) _say(context, m); }),
            const SizedBox(height: 20),
            if (store.state.locations.length > 1)
              TextButton.icon(onPressed: () { store.update((s) { s.locations.remove(l); if (s.lastLocationId == l.id) s.lastLocationId = s.locations.first.id; }); Navigator.pop(context); },
                  style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error), icon: const Icon(LucideIcons.trash2, size: 16), label: const Text('Remove this location')),
          ]),
        ),
      ]),
    ));
    setState(() {});
  }
}

/// One body figure to pick: its front and back, plain, with a selected ring like an option card.
class _FigureChoice extends StatelessWidget {
  const _FigureChoice({required this.figure, required this.selected, required this.onTap});
  final String figure;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final label = figure == 'female' ? 'Female' : 'Male';
    return Semantics(
      button: true, selected: selected, label: '$label figure',
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: m(context, durBase),
          curve: easeOut,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(
            color: selected ? du.accentSubtle : du.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? du.accentStrong : du.line, width: selected ? 1.5 : 0.6),
          ),
          child: ExcludeSemantics(child: Column(children: [
            IgnorePointer(child: FittedBox(
              child: MuscleFigure(highlight: const {}, figure: figure, height: 120, interactive: false, tooltip: false, clearAfter: null),
            )),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedSwitcher(
                duration: m(context, durBase),
                child: Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle, key: ValueKey(selected), size: 18, color: selected ? du.accentStrong : du.line),
              ),
              const SizedBox(width: 6),
              Text(label, style: t.titleSmall?.copyWith(color: selected ? du.accentText : du.ink)),
            ]),
          ])),
        ),
      ),
    );
  }
}

/// Takes a copy made by Copy your data from the clipboard after a confirm; Settings and the first onboarding page both
/// offer it. Notifications, the calendar and position come in off, since this install may not have their permissions
/// yet. Returns which of them the copy had on, or null when nothing changed.
Future<({bool notify, bool calendar, bool autoTrack, bool location})?> restoreCopiedData(BuildContext context) async {
  final store = context.store;
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger.showSnackBar(SnackBar(content: Text(text)));
  final raw = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
  if (!context.mounted) return null;
  if (raw == null || !Store.looksLikeData(raw)) { say('The clipboard holds no copied data. Copy it in the other install first.'); return null; }
  final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: const Text('Replace everything?'),
    content: const Text('Profile, locations, levels and history on this phone become the copied ones. There is no undo.'),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace'))],
  ));
  if (ok != true) return null;
  if (!store.importJson(raw)) { say('That data could not be read. Nothing changed.'); return null; }
  final s = store.state.settings;
  final want = (notify: s.notify, calendar: s.calendar, autoTrack: s.autoTrack, location: s.location);
  store.update((x) { x.settings.notify = false; x.settings.calendar = false; x.settings.autoTrack = false; x.settings.location = false; });
  return want;
}
