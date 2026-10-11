import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_dialog.dart';
import '../models/guest.dart';

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
    this.errorMessage,
    super.key,
  });

  final List<GuestGroup> groups;

  /// Guests per group id.
  final Map<String, int> guestCounts;
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
              ? 'لا يوجد ضيوف في هذه المجموعة.'
              : 'سيبقى $count من الضيوف في قائمتك بدون مجموعة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف المجموعة'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onDelete(group);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'مجموعات الضيوف',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'رتّب ضيوفك: الأهل، الأصدقاء، زملاء العمل…',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              for (final group in widget.groups)
                ListTile(
                  key: ValueKey('guest-group-${group.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.users),
                  title: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('${widget.guestCounts[group.id] ?? 0} ضيف'),
                  onTap: widget.saving ? null : () => _rename(group),
                  trailing: IconButton(
                    tooltip: 'حذف مجموعة ${group.name}',
                    onPressed: widget.saving ? null : () => _delete(group),
                    icon: const Icon(LucideIcons.trash2, size: 18),
                  ),
                ),
              if (widget.groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'لا توجد مجموعات بعد.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('guest-group-new-name'),
                      controller: _controller,
                      textAlign: TextAlign.right,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _create(),
                      decoration: const InputDecoration(
                        hintText: 'اسم مجموعة جديدة',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    key: const ValueKey('guest-group-add'),
                    tooltip: 'إضافة المجموعة',
                    onPressed: widget.saving ? null : _create,
                    icon: const Icon(LucideIcons.plus),
                  ),
                ],
              ),
              if (widget.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
