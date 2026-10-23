// Location editor (UI.md): a name, a template to fill from, a position (or anywhere), and the equipment that is
// there by group. Templates are suggestions that fill the name and the list; the location is always the user's own.
// Shared by onboarding and Settings.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import '../integrations.dart';
import 'app.dart';
import 'theme.dart';
import 'widgets.dart';

class LocationEditor extends StatefulWidget {
  const LocationEditor({super.key, required this.location, required this.onChanged, this.showPosition = true, this.say});
  final Location location;
  final VoidCallback onChanged;
  final bool showPosition;
  final void Function(String text)? say;
  @override
  State<LocationEditor> createState() => _LocationEditorState();
}

class _LocationEditorState extends State<LocationEditor> {
  late final nameCtl = TextEditingController(text: widget.location.name);
  bool locating = false;

  void _set(void Function() fn) { fn(); widget.onChanged(); setState(() {}); }

  void _fill(LocationTemplate x) => _set(() {
        widget.location
          ..name = x.name
          ..template = x.id
          ..equipment = x.equipment.toList();
        nameCtl.text = x.name;
      });

  Future<void> _pickTemplate(BuildContext context) async {
    final x = await showSheet<LocationTemplate>(context, ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 16), children: [
      const SheetHeader('Fill from a template', subtitle: 'Sets the name and the list. Change anything after.', icon: LucideIcons.mapPin),
      for (final x in templates)
        ListTile(
          leading: IconBadge(locationIcon(x.id), size: 36, accent: x.id == widget.location.template),
          title: Text(x.name), subtitle: Text(x.equipment.isEmpty ? 'bodyweight only' : '${x.equipment.length} item${x.equipment.length == 1 ? '' : 's'}'),
          onTap: () => Navigator.pop(context, x),
        ),
    ]));
    if (x != null) _fill(x);
  }

  Future<void> _savePosition() async {
    setState(() => locating = true);
    if (!await LocationBridge.requestPermission()) { widget.say?.call('Location access was not granted.'); if (mounted) setState(() => locating = false); return; }
    final p = await LocationBridge.current();
    if (!mounted) return;
    setState(() => locating = false);
    if (p == null) { widget.say?.call('Could not read the position. Try again outdoors or with location on.'); return; }
    _set(() { widget.location.lat = p.lat; widget.location.lng = p.lng; });
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.location;
    final t = Theme.of(context).textTheme;
    final du = context.du;
    final tpl = templates.where((x) => x.id == l.template).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: nameCtl,
        decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(LucideIcons.mapPin, size: 18)),
        onChanged: (v) => _set(() => l.name = v.trim().isEmpty ? 'My place' : v.trim()),
      ),
      const SizedBox(height: 12),
      Panel(padding: EdgeInsets.zero, clip: true, child: Row1(
        icon: locationIcon(l.template), title: const Text('Fill from a template'), subtitle: tpl?.name ?? 'Your own list', onTap: () => _pickTemplate(context),
      )),
      if (widget.showPosition) ...[
        const SizedBox(height: 16),
        QuietLine(l.hasPosition ? 'Position saved: picked for you within ${LocationBridge.nearbyMetres.round()} m, when position is on.' : 'Anywhere: never picked by distance, the fallback when nothing is near.', icon: l.hasPosition ? LucideIcons.locate : LucideIcons.globe),
        Row(children: [
          TextButton.icon(onPressed: locating ? null : _savePosition, icon: Icon(locating ? LucideIcons.loader : LucideIcons.locate, size: 16), label: Text(l.hasPosition ? 'Update my position' : 'Save my position')),
          if (l.hasPosition) TextButton.icon(onPressed: () => _set(() { l.lat = null; l.lng = null; }), icon: const Icon(LucideIcons.globe, size: 16), label: const Text('Make it anywhere')),
        ]),
      ],
      const SizedBox(height: 12),
      for (final g in equipmentGroups) ...[
        Padding(padding: const EdgeInsets.only(top: 14, bottom: 8), child: Row(children: [
          Expanded(child: Subhead(g.name, icon: equipmentGroupIcon(g.name))),
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(44, 32)),
            onPressed: () => _set(() { final all = g.items.keys.every(l.equipment.contains); if (all) { l.equipment.removeWhere(g.items.containsKey); } else { for (final k in g.items.keys) { if (!l.equipment.contains(k)) l.equipment.add(k); } } }),
            child: Text(g.items.keys.every(l.equipment.contains) ? 'Clear' : 'Tick all', style: t.labelMedium?.copyWith(color: du.accentText)),
          ),
        ])),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in g.items.entries)
            FilterChip(label: Text(e.value), selected: l.equipment.contains(e.key), onSelected: (v) => _set(() { if (v) { l.equipment.add(e.key); } else { l.equipment.remove(e.key); } })),
        ]),
      ],
      const SizedBox(height: 16),
      QuietLine('${l.equipment.length} items. Equipment decides which exercises fit here and how far a bodyweight progression goes.', icon: LucideIcons.info),
    ]);
  }
}
