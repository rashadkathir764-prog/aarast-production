import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_dialog.dart';
import '../models/task_checklist_item.dart';

/// The steps that make up one task. Each change is saved on its own, so the
/// list always shows what was saved; the parent decides where changes go.
class TaskChecklistSection extends StatefulWidget {
  const TaskChecklistSection({
    required this.items,
    required this.saving,
    required this.onAdd,
    required this.onToggle,
    required this.onRename,
    required this.onRemove,
    this.errorMessage,
    super.key,
  });

  final List<TaskChecklistItem> items;
  final bool saving;
  final String? errorMessage;

  /// Returns whether the step was saved, so the field clears only then.
  final Future<bool> Function(String title) onAdd;
  final void Function(TaskChecklistItem item, bool isDone) onToggle;
  final void Function(TaskChecklistItem item, String title) onRename;
  final void Function(TaskChecklistItem item) onRemove;

  @override
  State<TaskChecklistSection> createState() => _TaskChecklistSectionState();
}

class _TaskChecklistSectionState extends State<TaskChecklistSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _controller.text.trim();
    if (title.isEmpty || widget.saving) return;
    if (await widget.onAdd(title) && mounted) _controller.clear();
  }

  Future<void> _rename(TaskChecklistItem item) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameStepDialog(initialTitle: item.title),
    );
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == item.title) return;
    widget.onRename(item, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final done = items.where((item) => item.isDone).length;
    return AarastV3FormSurface(
      title: 'خطوات المهمة',
      subtitle: items.isEmpty
          ? 'قسّم المهمة إلى خطوات صغيرة تُنجز واحدة واحدة.'
          : 'أُنجز $done من ${items.length}',
      children: [
        for (final item in items)
          Row(
            key: ValueKey('task-checklist-item-${item.id}'),
            children: [
              Checkbox(
                value: item.isDone,
                onChanged: widget.saving
                    ? null
                    : (value) => widget.onToggle(item, value ?? false),
              ),
              Expanded(
                child: InkWell(
                  onTap: widget.saving ? null : () => _rename(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: item.isDone
                            ? AppTheme.textSecondary
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        decoration: item.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'حذف الخطوة ${item.title}',
                onPressed: widget.saving ? null : () => widget.onRemove(item),
                icon: const Icon(LucideIcons.trash2, size: 18),
              ),
            ],
          ),
        const SizedBox(height: AppTheme.space8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('task-checklist-new-item'),
                controller: _controller,
                textAlign: TextAlign.right,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(),
                decoration: const InputDecoration(
                  hintText: 'أضف خطوة، مثال: الاتصال بالقاعة',
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space8),
            IconButton.filledTonal(
              key: const ValueKey('task-checklist-add'),
              tooltip: 'إضافة الخطوة',
              onPressed: widget.saving ? null : _add,
              icon: const Icon(LucideIcons.plus),
            ),
          ],
        ),
        if (widget.errorMessage != null) ...[
          const SizedBox(height: AppTheme.space8),
          Text(
            widget.errorMessage!,
            style: const TextStyle(
              color: AppTheme.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

/// Owns its text controller so it is disposed only after the dialog route,
/// including its closing animation, is gone.
class _RenameStepDialog extends StatefulWidget {
  const _RenameStepDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameStepDialog> createState() => _RenameStepDialogState();
}

class _RenameStepDialogState extends State<_RenameStepDialog> {
  late final _controller = TextEditingController(text: widget.initialTitle);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AarastDialog(
      title: const Text('تعديل الخطوة'),
      content: TextField(
        key: const ValueKey('task-checklist-rename-field'),
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
