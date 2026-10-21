// Person state and the clock. Derived from attendance only.
import '../data/model.dart';

/// Calendar days from a to b: a session last night and a visit this morning count as one day.
int daysBetween(DateTime a, DateTime b) => DateTime(b.year, b.month, b.day).difference(DateTime(a.year, a.month, a.day)).inDays;

/// Calendar days from [at] to [now].
int daysAgo(DateTime at, DateTime now) => daysBetween(at, now);

/// How long ago, in words: "today", "yesterday", "3 days ago", "2 weeks ago", "long ago", or "not yet".
String agoText(DateTime? at, DateTime now) {
  if (at == null) return 'not yet';
  final d = daysAgo(at, now);
  return d == 0 ? 'today' : d == 1 ? 'yesterday' : d < 14 ? '$d days ago' : d < 60 ? '${d ~/ 7} weeks ago' : 'long ago';
}

class PersonView {
  PersonView(this.state, this.daysSince, this.last);
  final PersonState state;
  final int daysSince;
  final Session? last;
}

PersonView personState(AppState s, DateTime now) {
  final last = s.lastSession;
  if (last == null || last.endedAt == null) return PersonView(PersonState.active, 0, null);
  final days = daysBetween(last.endedAt!, now);
  if (days >= s.settings.daysAway) return PersonView(PersonState.away, days, last);
  if (days >= 3) return PersonView(PersonState.atRisk, days, last);
  return PersonView(PersonState.active, days, last);
}

/// One nudge per transition: returns the text to show, or null. Marks it as shown.
String? nudgeFor(AppState s, DateTime now) {
  final p = personState(s, now);
  if (p.state == PersonState.active || p.last == null) return null;
  final key = '${p.last!.id}:${p.state.name}';
  if (s.person.nudgedFor == key) return s.person.nudgeDismissed ? null : _nudgeText(p);
  s.person.nudgedFor = key;
  s.person.nudgeDismissed = false;
  return _nudgeText(p);
}

String _nudgeText(PersonView p) => p.state == PersonState.atRisk
    ? 'It has been ${p.daysSince} days. An easy workout or a walk counts.'
    : 'Welcome back. Today defaults to easy; nothing is lost.';
