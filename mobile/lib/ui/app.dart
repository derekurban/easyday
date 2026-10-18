// App shell: store scope, theme, and which screen is showing.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/store.dart';
import 'catalog.dart';
import 'onboarding.dart';
import 'progress.dart';
import 'session.dart';
import 'settings.dart';
import 'theme.dart';
import 'today.dart';
import 'updates.dart';

class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({super.key, required Store store, required super.child}) : super(notifier: store);
  static Store of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

extension StoreContext on BuildContext {
  Store get store => StoreScope.of(this);
}

class FitnessApp extends StatelessWidget {
  const FitnessApp(this.store, {super.key});
  final Store store;
  @override
  Widget build(BuildContext context) => StoreScope(
        store: store,
        child: MaterialApp(
          title: 'Fitness',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          home: const AutoUpdater(child: Shell()),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final store = context.store;
    final s = store.state;
    if (s.profile == null || s.plan == null) { tab = 0; return const OnboardingScreen(); }
    if (s.active != null) return const SessionScreen();
    final pages = const [TodayScreen(), ProgressScreen(), CatalogScreen(), SettingsScreen()];
    return Scaffold(
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.calendarDays), label: 'Today'),
          NavigationDestination(icon: Icon(LucideIcons.trendingUp), label: 'Progress'),
          NavigationDestination(icon: Icon(LucideIcons.dumbbell), label: 'Exercises'),
          NavigationDestination(icon: Icon(LucideIcons.slidersHorizontal), label: 'Settings'),
        ],
      ),
    );
  }
}

/// Two or three labelled options, full width. Kept for the few true either-or picks such as units.
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.value, required this.options, required this.onChanged, this.icons});
  final T value;
  final Map<T, String> options;
  final Map<T, IconData>? icons;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: SegmentedButton<T>(
          segments: [for (final e in options.entries) ButtonSegment(value: e.key, label: Text(e.value), icon: icons?[e.key] == null ? null : Icon(icons![e.key], size: 16))],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (v) => onChanged(v.first),
        ),
      );
}

String mmss(double seconds) {
  final s = seconds.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

Future<T?> showSheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), child: child),
    );

/// A sheet with a title row and an optional subtitle.
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {super.key, this.subtitle, this.icon});
  final String title;
  final String? subtitle;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final du = context.du;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(children: [
        if (icon != null) Padding(padding: const EdgeInsets.only(right: 10), child: Icon(icon, size: 22, color: du.inkSecondary)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: t.headlineMedium),
          if (subtitle != null) Text(subtitle!, style: t.bodySmall),
        ])),
      ]),
    );
  }
}
