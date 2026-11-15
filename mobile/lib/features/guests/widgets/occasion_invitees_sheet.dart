import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_sort.dart';
import '../models/guest.dart';
import '../providers/guests_provider.dart';
import '../utils/guest_display.dart';

/// D116: who is invited to one occasion beyond the wedding, chosen a whole
/// group at a time or guest by guest. Saving changes only the guests whose
/// invitation changed; an answer a kept guest gave stays. Every guest is
/// invited to the wedding, so it is never chosen here.
class OccasionInviteesSheet extends StatefulWidget {
  const OccasionInviteesSheet({
    required this.provider,
    required this.weddingPlanId,
    required this.eventId,
    required this.label,
    super.key,
  });

  final GuestsProvider provider;
  final String weddingPlanId;
  final String eventId;
  final String label;

  @override
  State<OccasionInviteesSheet> createState() => _OccasionInviteesSheetState();
}

class _OccasionInviteesSheetState extends State<OccasionInviteesSheet> {
  late final List<Guest> _guests = [
    for (final guest in widget.provider.guests)
      if (guest.weddingPlanId == widget.weddingPlanId && guest.editable) guest,
  ]..sort((a, b) => compareArabicNames(a.name, b.name));
  late final Set<String> _before = {
    for (final guest in _guests)
      if (guest.eventIds.contains(widget.eventId)) guest.id,
  };
  late final Set<String> _chosen = {..._before};
  bool _saving = false;
  int _done = 0;
  String? _error;

  List<Guest> get _changed => [
    for (final guest in _guests)
      if (_before.contains(guest.id) != _chosen.contains(guest.id)) guest,
  ];

  void _toggleGroup(List<Guest> members) {
    final all = members.every((guest) => _chosen.contains(guest.id));
    setState(() {
      for (final guest in members) {
        all ? _chosen.remove(guest.id) : _chosen.add(guest.id);
      }
    });
  }

  Future<void> _save() async {
    final changed = _changed;
    setState(() {
      _saving = true;
      _done = 0;
      _error = null;
    });
    for (final guest in changed) {
      final ids = [
        for (final id in guest.eventIds)
          if (id != widget.eventId) id,
        if (_chosen.contains(guest.id)) widget.eventId,
      ];
      final ok = await widget.provider.updateGuest(guest: guest, eventIds: ids);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _saving = false;
          _error =
              widget.provider.errorMessage ??
              'ما انحفظ ${guest.name}. اللي قبله انحفظ.';
        });
        return;
      }
      setState(() => _done++);
    }
    if (mounted) Navigator.of(context).pop(changed.length);
  }

  @override
  Widget build(BuildContext context) {
    final words = GuestWords.of(context);
    final groups = <({String name, List<Guest> members})>[
      for (final group in widget.provider.groups)
        if (group.weddingPlanId == widget.weddingPlanId)
          (
            name: group.name,
            members: [
              for (final guest in _guests)
                if (guest.groupId == group.id) guest,
            ],
          ),
    ]..removeWhere((group) => group.members.isEmpty);
    final changed = _changed.length;
    return JourneySheetBody(
      title: 'مدعوين ${widget.label}',
      subtitle: '${words.count(_chosen.length)} من ${_guests.length}',
      bottom: JourneyButton(
        key: const ValueKey('invitees-save'),
        label: _saving
            ? 'نحفظ $_done من $changed'
            : changed == 0
            ? 'ما تغيّر شي'
            : '${context.say('احفظ', 'احفظي')} (${words.count(changed)})',
        expand: true,
        large: true,
        loading: _saving,
        onPressed: _saving || changed == 0 ? null : _save,
      ),
      children: [
        if (groups.isNotEmpty) ...[
          const JourneySectionTitle('مجموعة كاملة'),
          Wrap(
            spacing: AarastV3Space.x2,
            runSpacing: AarastV3Space.x2,
            children: [
              for (final group in groups)
                JourneyChip(
                  key: ValueKey('invitees-group-${group.name}'),
                  label:
                      '${group.name} ${group.members.where((guest) => _chosen.contains(guest.id)).length}/${group.members.length}',
                  selected: group.members.every(
                    (guest) => _chosen.contains(guest.id),
                  ),
                  selectedColor: context.accent.primary,
                  onTap: _saving ? null : () => _toggleGroup(group.members),
                ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        JourneySectionTitle(words.guests),
        if (_guests.isEmpty)
          JourneyNote(
            text: context.say(
              'ما فيه ${words.guests} بعد. أضفهم من «+» في الضيوف.',
              'ما فيه ${words.guests} بعد. أضيفيهم من «+» في الضيوف.',
            ),
            icon: LucideIcons.userPlus,
          ),
        for (final guest in _guests)
          CheckboxListTile(
            key: ValueKey('invitees-guest-${guest.id}'),
            value: _chosen.contains(guest.id),
            onChanged: _saving
                ? null
                : (value) => setState(
                    () => value == true
                        ? _chosen.add(guest.id)
                        : _chosen.remove(guest.id),
                  ),
            title: Text(guest.name, style: JourneyType.of(JourneyType.body)),
            activeColor: context.accent.primary,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        if (_error case final error?) ...[
          const SizedBox(height: AarastV3Space.x2),
          Text(
            error,
            key: const ValueKey('invitees-error'),
            style: JourneyType.of(
              JourneyType.bodySmall,
              weight: JourneyType.bold,
              color: AarastV3Color.danger,
            ),
          ),
        ],
      ],
    );
  }
}
