// Location editor: a name, a position (or anywhere), and the equipment that is there. Templates are suggestions that
// fill the name and the list; the location is always the user's own. Shared by onboarding and Settings.
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/library.dart';
import '../data/model.dart';
import '../integrations.dart';
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: nameCtl,
        decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(LucideIcons.mapPin, size: 18)),
        onChanged: (v) => _set(() => l.name = v.trim().isEmpty ? 'My place' : v.trim()),
      ),
      const SizedBox(height: 12),
      Text('Fill from a template', style: t.labelMedium),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final x in templates)
          ActionChip(avatar: Icon(locationIcon(x.id), size: 16), label: Text(x.name), onPressed: () => _fill(x)),
      ]),
      if (widget.showPosition) ...[
        const SizedBox(height: 14),
        Row(children: [
          Icon(l.hasPosition ? LucideIcons.locate : LucideIcons.globe, size: 16, color: du.inkSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(l.hasPosition ? 'Position saved. Picked for you when you are within ${LocationBridge.nearbyMetres.round()} m, if position is on.' : 'Anywhere: no fixed place. Never picked by distance, and the fallback when nothing is near.', style: t.bodySmall)),
        ]),
        Row(children: [
          TextButton.icon(onPressed: locating ? null : _savePosition, icon: Icon(locating ? LucideIcons.loader : LucideIcons.locate, size: 16), label: Text(l.hasPosition ? 'Update my position' : 'Save my position')),
          if (l.hasPosition) TextButton.icon(onPressed: () => _set(() { l.lat = null; l.lng = null; }), icon: const Icon(LucideIcons.globe, size: 16), label: const Text('Make it anywhere')),
        ]),
      ],
      const SizedBox(height: 6),
      Text('${l.equipment.length} items ticked. Equipment decides which exercises you can do here and how far a bodyweight progression goes.', style: t.bodySmall),
      for (final g in equipmentGroups) ...[
        Padding(padding: const EdgeInsets.only(top: 16, bottom: 6), child: Row(children: [
          Icon(equipmentGroupIcon(g.name), size: 14, color: du.inkTertiary), const SizedBox(width: 6), Text(g.name, style: t.labelMedium),
          const Spacer(),
          TextButton(
            onPressed: () => _set(() { final all = g.items.keys.every(l.equipment.contains); if (all) { l.equipment.removeWhere(g.items.containsKey); } else { for (final k in g.items.keys) { if (!l.equipment.contains(k)) l.equipment.add(k); } } }),
            child: Text(g.items.keys.every(l.equipment.contains) ? 'none' : 'all', style: t.labelMedium?.copyWith(color: du.accentText)),
          ),
        ])),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in g.items.entries)
            FilterChip(label: Text(e.value), selected: l.equipment.contains(e.key), onSelected: (v) => _set(() { if (v) { l.equipment.add(e.key); } else { l.equipment.remove(e.key); } })),
        ]),
      ],
    ]);
  }
}
