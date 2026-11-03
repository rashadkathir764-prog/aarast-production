import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_dialog.dart';
import '../models/guest.dart';
import '../utils/guest_display.dart';

/// Create, rename and delete guest groups (family, friends, colleagues…).
/// Presentational: the caller saves each change and passes the current
/// groups back in, so the list only shows what was saved.
class GuestGroupsSheet extends StatefulWidget {
  const GuestGroupsSheet({
    required this.groups,
    required this.guestCounts,
    required this.saving,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
    this.ungroupedCount = 0,
    this.errorMessage,
    super.key,
  });

  final List<GuestGroup> groups;

  /// Guests per group id.
  final Map<String, int> guestCounts;

  /// Guests without a group, shown as its own row.
  final int ungroupedCount;
  final bool saving;
  final String? errorMessage;
  final Future<bool> Function(String name) onCreate;
  final Future<bool> Function(GuestGroup group, String name) onRename;
  final Future<bool> Function(GuestGroup group) onDelete;

  @override
  State<GuestGroupsSheet> createState() => _GuestGroupsSheetState();
}

class _GuestGroupsSheetState extends State<GuestGroupsSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty || widget.saving) return;
    if (await widget.onCreate(name) && mounted) _controller.clear();
  }

  Future<void> _rename(GuestGroup group) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _GroupNameDialog(initialName: group.name),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == group.name) return;
    await widget.onRename(group, trimmed);
  }

  Future<void> _delete(GuestGroup group) async {
    final count = widget.guestCounts[group.id] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: Text('حذف مجموعة «${group.name}»؟'),
        content: Text(
          count == 0
              ? context.planWord('ما فيها ضيوف.', 'ما فيها ضيفات.')
              : context.planWord(
                  'ضيوفها ($count) يبقون في قائمتك بدون مجموعة.',
                  'ضيفاتها ($count) يبقين في قائمتك بدون مجموعة.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AarastV3Color.danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.say('شيل المجموعة', 'شيلي المجموعة')),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onDelete(group);
  }

  @override
  Widget build(BuildContext context) {
    final count = GuestWords.of(context).count;
    return JourneySheetBody(
      title: 'المجموعات',
      subtitle:
          '${context.say('رتّب', 'رتّبي')} '
          '${context.planWord('ضيوفك: الأهل، الأصحاب، زملاء الشغل…', 'ضيفاتك: الأهل، الصاحبات، زميلات الشغل…')}',
      children: [
        JourneyBox(
          padding: EdgeInsets.zero,
          child: JourneyList(
            children: [
              for (final group in widget.groups)
                JourneyListRow(
                  key: ValueKey('guest-group-${group.id}'),
                  icon: LucideIcons.users,
                  color: context.accent.primary,
                  soft: context.accent.primarySoft,
                  title: group.name,
                  subtitle: count(widget.guestCounts[group.id] ?? 0),
                  // D80: another's group is read, not renamed or removed.
                  onTap: widget.saving || !group.editable
                      ? null
                      : () => _rename(group),
                  trailing: group.editable
                      ? IconButton(
                          tooltip:
                              '${context.say('شيل', 'شيلي')} مجموعة ${group.name}',
                          onPressed: widget.saving
                              ? null
                              : () => _delete(group),
                          icon: const Icon(
                            LucideIcons.trash2,
                            size: 18,
                            color: AarastV3Color.textFaint,
                          ),
                        )
                      : null,
                ),
              JourneyListRow(
                icon: LucideIcons.userX,
                color: AarastV3Color.textFaint,
                soft: AarastV3Color.line,
                title: 'بدون مجموعة',
                subtitle: count(widget.ungroupedCount),
              ),
            ],
          ),
        ),
        const SizedBox(height: AarastV3Space.x3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: JourneyTextField(
                key: const ValueKey('guest-group-new-name'),
                label: 'مجموعة جديدة',
                hint: 'مثلًا: الحارة',
                controller: _controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _create(),
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            JourneyRoundButton(
              key: const ValueKey('guest-group-add'),
              icon: LucideIcons.plus,
              tooltip: context.say('أضف المجموعة', 'أضيفي المجموعة'),
              onPressed: widget.saving ? null : _create,
            ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x2),
        Text(
          context.say(
            'شيل المجموعة ما يشيل ضيوفها، ينقلهم «بدون مجموعة». اضغط على مجموعة تغيّر اسمها.',
            'شيل المجموعة ما يشيل ضيفاتها، ينقلهن «بدون مجموعة». اضغطي على مجموعة تغيّرين اسمها.',
          ),
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
        if (widget.errorMessage != null) ...[
          const SizedBox(height: AarastV3Space.x2),
          Text(
            widget.errorMessage!,
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: AarastV3Color.danger,
            ),
          ),
        ],
      ],
    );
  }
}

/// Owns its controller so it is disposed after the dialog route is gone.
class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AarastDialog(
      title: const Text('تعديل اسم المجموعة'),
      content: TextField(
        key: const ValueKey('guest-group-rename-field'),
        controller: _controller,
        autofocus: true,
        textAlign: TextAlign.right,
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
