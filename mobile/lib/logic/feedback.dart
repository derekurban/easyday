// Feedback: problems and ideas go to GitHub Issues on the app's public repo, through the issue forms in
// .github/ISSUE_TEMPLATE. The person writes the report in the app; the app opens the form in the browser with every
// field filled in, so on GitHub they only sign in and send. The build and the phone are added; nothing else about them
// is (no history, places, calendar or goal), because issues are public. This file is the pure part: the fields, the
// draft, the lines that get added, and the links.
import 'update.dart';

enum Report { problem, idea }

/// The issue form each kind opens, a file in .github/ISSUE_TEMPLATE.
const reportTemplate = {Report.problem: 'bug.yml', Report.idea: 'feature.yml'};

/// A text field of a report, written in the app and carried to the form field with the same [id].
class ReportField {
  const ReportField(this.id, this.label, {this.hint = '', this.required = false, this.lines = 3, this.max = 1500});
  final String id, label, hint;
  final bool required;
  final int lines, max;
}

const reportFields = {
  Report.problem: [
    ReportField('what', 'What happened', hint: 'What you saw, and on which screen.', required: true, lines: 4),
    ReportField('expected', 'What you expected', lines: 2, max: 600),
    ReportField('steps', 'How to make it happen again', hint: 'The taps that lead to it, if you know them.'),
  ],
  Report.idea: [
    ReportField('idea', 'The idea', hint: 'What you would like the app to do.', required: true, lines: 4),
    ReportField('why', 'Why it would help', hint: 'The moment it would have helped.', max: 1000),
  ],
};

/// How often a problem happens, carried to the form's `often` field.
const reportOften = ['Every time', 'Sometimes', 'Once so far'];

const reportTitleMax = 120;

/// Every form field (by id) the app fills for [kind]. test/feedback_test.dart checks each is a text field in its form.
List<String> reportIds(Report kind) =>
    [for (final f in reportFields[kind]!) f.id, if (kind == Report.problem) ...['often', 'device'], 'version'];

/// A report being written. It outlives the sheet, so closing it or a failed sign-in loses nothing.
class ReportDraft {
  ReportDraft(this.kind);
  final Report kind;
  String title = '';
  final Map<String, String> text = {};
  String often = '';
  /// Set once it has been carried to GitHub; the sheet then offers to clear it.
  bool carried = false;

  bool get ready => title.trim().isNotEmpty && reportFields[kind]!.where((f) => f.required).every((f) => (text[f.id] ?? '').trim().isNotEmpty);
  bool get isEmpty => title.trim().isEmpty && text.values.every((v) => v.trim().isEmpty) && often.isEmpty;

  void clear() { title = ''; text.clear(); often = ''; carried = false; }
}

/// Open issues, newest first.
final reportsUrl = Uri.https('github.com', '/$updateRepo/issues', {'q': 'is:issue is:open sort:created-desc'});

/// The build as one line: "0.13.7 (build 100042) · staging", or "0.13.7 (build 100042)" for prod.
String buildLine(String versionName, int versionCode, String flavor) =>
    '${versionParts(versionName).join('.')}${versionCode > 0 ? ' (build $versionCode)' : ''}${flavor == 'staging' ? ' · staging' : ''}';

/// The phone as one line: "Google Pixel 9 Pro · Android 16 (API 36)". The maker is left out when the model already
/// starts with it, and missing parts are skipped.
String deviceLine({String maker = '', String model = '', String android = '', int sdk = 0}) {
  final name = maker.isEmpty || model.toLowerCase().startsWith(maker.toLowerCase()) ? model : '$maker $model';
  final os = android.isEmpty ? '' : 'Android $android${sdk > 0 ? ' (API $sdk)' : ''}';
  return [name.trim(), os].where((s) => s.isNotEmpty).join(' · ');
}

/// GitHub answers 414 above its URL limit; stay well under it.
const reportUrlMax = 6000;

/// The new-issue link for [d]: the form, the title, and every field with something in it. When the link would pass
/// [reportUrlMax], the longest written field is shortened (ending in "…") until it fits, and `trimmed` says so.
({Uri url, bool trimmed}) reportUrl(ReportDraft d, {String version = '', String device = ''}) {
  final values = <String, String>{
    for (final f in reportFields[d.kind]!) f.id: _cut(d.text[f.id] ?? '', f.max),
    if (d.kind == Report.problem) 'often': d.often,
    'version': _cut(version, 120),
    if (d.kind == Report.problem) 'device': _cut(device, 120),
  }..removeWhere((_, v) => v.isEmpty);
  Uri build() => Uri.https('github.com', '/$updateRepo/issues/new', {
        'template': reportTemplate[d.kind]!,
        if (d.title.trim().isNotEmpty) 'title': _cut(d.title, reportTitleMax),
        ...values,
      });
  final written = {for (final f in reportFields[d.kind]!) f.id};
  var url = build();
  var trimmed = false;
  while (url.toString().length > reportUrlMax) {
    final longest = values.keys.where(written.contains).fold<String?>(null, (a, k) => a == null || values[k]!.length > values[a]!.length ? k : a);
    if (longest == null || values[longest]!.length <= 1) break;
    final v = values[longest]!;
    // an encoded character takes up to nine characters of the link, a plain one one: cut a ninth of the excess, at least 40
    final excess = url.toString().length - reportUrlMax;
    final keep = v.length - (excess ~/ 9 < 40 ? 40 : excess ~/ 9);
    values[longest] = keep <= 0 ? '…' : '${v.substring(0, keep).trimRight()}…';
    trimmed = true;
    url = build();
  }
  return (url: url, trimmed: trimmed);
}

/// The whole report as Markdown, laid out like the issue GitHub makes from the form; copied when the link had to be
/// shortened, so nothing written is lost.
String reportText(ReportDraft d, {String version = '', String device = ''}) {
  final out = StringBuffer(d.title.trim());
  void section(String label, String v) { if (v.trim().isNotEmpty) out.write('\n\n### $label\n\n${v.trim()}'); }
  for (final f in reportFields[d.kind]!) { section(f.label, d.text[f.id] ?? ''); }
  if (d.kind == Report.problem) section('How often', d.often);
  section('App version', version);
  if (d.kind == Report.problem) section('Phone', device);
  return out.toString();
}

String _cut(String s, int max) {
  final t = s.trim();
  return t.length > max ? t.substring(0, max) : t;
}
