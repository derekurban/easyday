// The Updates panel in Settings (which build this is, whether GitHub has a newer release, and the download and install
// flow for it) and the AutoUpdater, which does the same on its own whenever the app opens. The pure parts live in
// logic/update.dart; the platform calls in integrations.dart.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../integrations.dart';
import '../logic/update.dart';
import 'app.dart';
import 'theme.dart';
import 'widgets.dart';

enum _Phase { checking, upToDate, available, downloading, ready, installing, offline, none }

class UpdatePanel extends StatefulWidget {
  const UpdatePanel({super.key});
  @override
  State<UpdatePanel> createState() => _UpdatePanelState();
}

class _UpdatePanelState extends State<UpdatePanel> {
  AppInfo? info;
  ReleaseInfo? latest;
  _Phase phase = _Phase.checking;
  double progress = 0;
  String? path;
  String? error;

  StreamSubscription<({int status, String? message})>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = UpdateBridge.statuses.listen((s) {
      if (!mounted || s.status == 0 || s.status == -1) return;
      setState(() { phase = _Phase.available; error = 'Android did not install it${s.message == null ? '' : ': ${s.message}'}.'; });
    });
    _check();
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  Future<void> _check() async {
    setState(() { phase = _Phase.checking; error = null; });
    info ??= await UpdateBridge.appInfo();
    final got = await UpdateBridge.latest(info?.flavor);
    if (!mounted) return;
    final r = got.release;
    if (r == null) { setState(() => phase = got.reachable ? _Phase.none : _Phase.offline); return; }
    latest = r;
    final newer = info != null && isNewer(r, info!.versionName, info!.versionCode);
    setState(() => phase = newer ? _Phase.available : _Phase.upToDate);
  }

  Future<void> _update() async {
    final r = latest;
    if (r == null || info == null) return;
    final url = r.assets[assetFor(info!.flavor)];
    if (url == null) { setState(() => error = 'This release has no ${assetFor(info!.flavor)}.'); return; }
    if (!await UpdateBridge.canInstall()) {
      await UpdateBridge.openInstallSettings();
      if (!mounted) return;
      setState(() => error = 'Allow installs from this app, then tap Update again.');
      return;
    }
    setState(() { phase = _Phase.downloading; progress = 0; error = null; });
    final file = await UpdateBridge.download(url, assetFor(info!.flavor), (p) { if (mounted) setState(() => progress = p); });
    if (!mounted) return;
    if (file == null) { setState(() { phase = _Phase.available; error = 'The download failed. Check the connection and try again.'; }); return; }
    path = file;
    setState(() => phase = _Phase.ready);
    await _install();
  }

  Future<void> _install() async {
    if (path == null) return;
    setState(() => phase = _Phase.installing);
    final ok = await UpdateBridge.install(path!);
    if (!mounted) return;
    setState(() { phase = ok ? _Phase.ready : _Phase.available; if (!ok) error = 'Android would not open the installer.'; });
  }

  @override
  Widget build(BuildContext context) {
    final du = context.du;
    final t = Theme.of(context).textTheme;
    final version = info == null ? '…' : '${versionParts(info!.versionName).join('.')}${info!.flavor == 'staging' ? ' (build ${info!.versionCode})' : ''}';
    final (String status, Widget? action) = switch (phase) {
      _Phase.checking => ('Checking GitHub for a newer build…', null),
      _Phase.upToDate => ('Up to date.${latest?.at == null ? '' : ' Latest release ${_date(latest!.at!)}.'}', OutlinedButton(onPressed: _check, child: const Text('Check'))),
      _Phase.offline => ('Could not reach GitHub.', OutlinedButton(onPressed: _check, child: const Text('Retry'))),
      _Phase.none => ('No release published yet.', OutlinedButton(onPressed: _check, child: const Text('Check'))),
      _Phase.available => ('${releaseLabel(latest!)} is available.', FilledButton(onPressed: _update, child: const Text('Update'))),
      _Phase.downloading => ('Downloading ${releaseLabel(latest!)}… ${(progress * 100).round()} %', null),
      _Phase.ready => ('Installing ${releaseLabel(latest!)}. The app closes and the new version opens next time.', OutlinedButton(onPressed: _install, child: const Text('Install'))),
      _Phase.installing => ('Opening the installer…', null),
    };
    return Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const IconBadge(LucideIcons.download, size: 36),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Version $version${info?.flavor == 'staging' ? ' · staging' : ''}', style: t.bodyLarge),
          Text(status, style: t.bodySmall),
        ])),
        if (action != null) ...[const SizedBox(width: 12), action],
      ]),
      if (phase == _Phase.downloading) Padding(padding: const EdgeInsets.only(top: 10), child: LinearProgressIndicator(value: progress, minHeight: 4, borderRadius: BorderRadius.circular(2))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error))),
      if (phase == _Phase.available && latest!.notes.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 10), child: Text(latest!.notes, style: t.bodySmall?.copyWith(color: du.ink))),
    ]));
  }

  String _date(DateTime d) => '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';
}

/// Keeps the app current on its own: on launch, and whenever it comes back to the front (at most every half hour), it
/// asks GitHub for a newer build of this flavour, downloads it and installs it over itself, closing the app. It waits
/// while a workout is in progress. It stays off in debug builds (the dev loop's build is signed with the debug key and
/// cannot take a release build), until installs from this app are allowed (the Settings panel asks for that), and for
/// the rest of the run once an install has failed.
class AutoUpdater extends StatefulWidget {
  const AutoUpdater({super.key, required this.child});
  final Widget child;
  @override
  State<AutoUpdater> createState() => _AutoUpdaterState();
}

class _AutoUpdaterState extends State<AutoUpdater> with WidgetsBindingObserver {
  static const every = Duration(minutes: 30);
  DateTime? checked;
  bool busy = false, failed = false;
  StreamSubscription<({int status, String? message})>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = UpdateBridge.statuses.listen((s) { if (s.status != 0 && s.status != -1) failed = true; });
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _run(); }

  bool get _working => context.store.state.active != null;

  Future<void> _run() async {
    if (!kReleaseMode || busy || failed || !mounted || _working) return;
    if (checked != null && DateTime.now().difference(checked!) < every) return;
    busy = true;
    try {
      checked = DateTime.now();
      final info = await UpdateBridge.appInfo();
      if (info == null) return;
      final r = (await UpdateBridge.latest(info.flavor)).release;
      if (r == null || !isNewer(r, info.versionName, info.versionCode)) return;
      final url = r.assets[assetFor(info.flavor)];
      if (url == null || !await UpdateBridge.canInstall()) return;
      final path = await UpdateBridge.download(url, assetFor(info.flavor), (_) {});
      if (path == null || !mounted || _working) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('Updating to ${releaseLabel(r)}. The app will close; open it again.')));
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || _working) return;
      if (!await UpdateBridge.install(path)) failed = true;
    } finally {
      busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
