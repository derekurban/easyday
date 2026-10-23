// The Feedback panel in Settings: report a problem or suggest a feature as a GitHub issue, or see what is reported.
// The report is written here, in a sheet shaped like the issue form; "Continue on GitHub" opens the form in the browser
// with everything filled in, so there the person only signs in and sends. Drafts outlive the sheet, so closing it or a
// failed sign-in loses nothing. The fields, links and lines are in logic/feedback.dart.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../integrations.dart';
import '../logic/feedback.dart';
import 'app.dart';
import 'theme.dart';
import 'widgets.dart';

/// One draft per kind, kept while the app runs.
final _drafts = {for (final k in Report.values) k: ReportDraft(k)};

class FeedbackPanel extends StatefulWidget {
  const FeedbackPanel({super.key});
  @override
  State<FeedbackPanel> createState() => _FeedbackPanelState();
}

class _FeedbackPanelState extends State<FeedbackPanel> {
  AppInfo? info;

  @override
  void initState() {
    super.initState();
    UpdateBridge.appInfo().then((i) { if (mounted) setState(() => info = i); });
  }

  @override
  Widget build(BuildContext context) {
    final du = context.du;
    return Panel(padding: EdgeInsets.zero, clip: true, child: Column(children: [
      Row1(icon: LucideIcons.bug, title: const Text('Report a problem'), subtitle: 'Something broke or looks wrong.', onTap: () => _write(context, Report.problem)),
      const Divider(height: 1),
      Row1(icon: LucideIcons.lightbulb, title: const Text('Suggest a feature'), subtitle: 'An idea to make training easier.', onTap: () => _write(context, Report.idea)),
      const Divider(height: 1),
      Row1(icon: LucideIcons.listTodo, title: const Text('See what is reported'), subtitle: 'Open problems and ideas, on GitHub.',
          chevron: false, trailing: Icon(LucideIcons.externalLink, size: 16, color: du.inkTertiary), onTap: () => _open(context, reportsUrl)),
    ]));
  }

  Future<void> _write(BuildContext context, Report kind) async {
    final version = info == null ? '' : buildLine(info!.versionName, info!.versionCode, info!.flavor);
    final device = info == null ? '' : deviceLine(maker: info!.maker, model: info!.model, android: info!.android, sdk: info!.sdk);
    final d = _drafts[kind]!;
    final go = await showSheet<bool>(context, _ReportSheet(draft: d, version: version, device: device));
    if (go != true || !context.mounted) return;
    final r = reportUrl(d, version: version, device: device);
    d.carried = true;
    if (r.trimmed) {
      await Clipboard.setData(ClipboardData(text: reportText(d, version: version, device: device)));
      if (context.mounted) _say(context, 'Too long for one link, so it was shortened. The full text is copied; paste it on GitHub.');
    }
    if (context.mounted) await _open(context, r.url);
  }

  /// Opens [url] in the browser, or copies it when nothing on the phone can open it.
  Future<void> _open(BuildContext context, Uri url) async {
    if (await LinkBridge.open(url)) return;
    await Clipboard.setData(ClipboardData(text: url.toString()));
    if (context.mounted) _say(context, 'No browser to open it in. The link is copied.');
  }

  void _say(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// The report, written in the app. Pops true to carry it to GitHub.
class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.draft, required this.version, required this.device});
  final ReportDraft draft;
  final String version, device;
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  late final title = TextEditingController(text: widget.draft.title);
  late final fields = {for (final f in reportFields[widget.draft.kind]!) f.id: TextEditingController(text: widget.draft.text[f.id] ?? '')};

  ReportDraft get d => widget.draft;
  bool get problem => d.kind == Report.problem;

  @override
  void dispose() {
    title.dispose();
    for (final c in fields.values) { c.dispose(); }
    super.dispose();
  }

  void _clear() => setState(() {
        d.clear();
        title.clear();
        for (final c in fields.values) { c.clear(); }
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final added = [
      if (widget.version.isNotEmpty) ('Version', widget.version),
      if (problem && widget.device.isNotEmpty) ('Phone', widget.device),
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      child: ListView(shrinkWrap: true, padding: EdgeInsets.fromLTRB(0, 0, 0, 20 + MediaQuery.viewPaddingOf(context).bottom), children: [
        SheetHeader(problem ? 'Report a problem' : 'Suggest a feature',
            subtitle: 'Write it here; on GitHub you only sign in and send.', icon: problem ? LucideIcons.bug : LucideIcons.lightbulb),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (d.carried) ...[
              Panel(sunk: true, padding: const EdgeInsets.fromLTRB(12, 4, 4, 4), child: Row(children: [
                Icon(LucideIcons.circleCheck, size: 16, color: du.inkSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text('Already taken to GitHub. Sent it? Clear it to write another.', style: t.bodySmall)),
                TextButton(onPressed: _clear, child: const Text('Clear')),
              ])),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: title,
              maxLength: reportTitleMax,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'In a few words', hintText: problem ? 'Rest timer skips the last set' : 'A stretching day', counterText: ''),
              onChanged: (v) => setState(() => d.title = v),
            ),
            for (final f in reportFields[d.kind]!) ...[
              const SizedBox(height: 12),
              TextField(
                controller: fields[f.id],
                minLines: f.lines,
                maxLines: f.lines + 4,
                maxLength: f.max,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: f.required ? f.label : '${f.label} (optional)', hintText: f.hint.isEmpty ? null : f.hint, alignLabelWithHint: true, counterText: ''),
                onChanged: (v) => setState(() => d.text[f.id] = v),
              ),
            ],
            if (problem) ...[
              const SizedBox(height: 16),
              Text('How often', style: t.labelMedium),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final o in reportOften)
                  ChoiceChip(label: Text(o), selected: d.often == o, onSelected: (on) => setState(() => d.often = on ? o : '')),
              ]),
            ],
            if (added.isNotEmpty) ...[
              const SizedBox(height: 16),
              Panel(sunk: true, padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Added for you', style: t.labelMedium),
                const SizedBox(height: 8),
                for (final (label, value) in added)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(width: 64, child: Text(label, style: t.bodySmall?.copyWith(color: du.inkTertiary))),
                    Expanded(child: Text(value, style: t.bodySmall?.copyWith(color: du.ink))),
                  ])),
              ])),
            ],
            const SizedBox(height: 12),
            Text('Sending needs a free GitHub account, and reports there are public, so leave out anything personal. A screenshot can be added on GitHub before you send.',
                style: t.bodySmall),
            const SizedBox(height: 16),
            Row(children: [
              if (!d.isEmpty && !d.carried) TextButton(onPressed: _clear, child: const Text('Clear')),
              const Spacer(),
              FilledButton.icon(onPressed: d.ready ? () => Navigator.pop(context, true) : null, icon: const Icon(LucideIcons.externalLink, size: 18), label: const Text('Continue on GitHub')),
            ]),
          ]),
        ),
      ]),
    );
  }
}
