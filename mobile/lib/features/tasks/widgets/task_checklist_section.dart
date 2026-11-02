import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
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
    final title = await showJourneySheet<String>(
      context: context,
      builder: (_) => _RenameStepSheet(initialTitle: item.title),
    );
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == item.title) return;
    widget.onRename(item, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JourneySectionTitle('خطوات صغيرة'),
        JourneyBox(
          padding: const EdgeInsets.fromLTRB(
            AarastV3Space.x2,
            AarastV3Space.x1,
            AarastV3Space.x2,
            AarastV3Space.x2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AarastV3Space.x2,
                    AarastV3Space.x2,
                    AarastV3Space.x2,
                    AarastV3Space.x1,
                  ),
                  child: Text(
                    context.say(
                      'قسّمها على خطوات صغيرة تخلصها وحدة وحدة.',
                      'قسّميها على خطوات صغيرة تخلصينها وحدة وحدة.',
                    ),
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ),
              for (final item in items)
                Row(
                  key: ValueKey('task-checklist-item-${item.id}'),
                  children: [
                    Checkbox(
                      value: item.isDone,
                      shape: const CircleBorder(),
                      activeColor: AarastV3Color.mint,
                      onChanged: widget.saving
                          ? null
                          : (value) => widget.onToggle(item, value ?? false),
                    ),
                    Expanded(
                      child: AarastPressable(
                        onTap: widget.saving ? () {} : () => _rename(item),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AarastV3Space.x2,
                          ),
                          child: Text(
                            item.title,
                            style:
                                JourneyType.of(
                                  JourneyType.body,
                                  color: item.isDone
                                      ? AarastV3Color.textMuted
                                      : AarastV3Color.ink,
                                ).copyWith(
                                  decoration: item.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip:
                          '${context.say('شيل', 'شيلي')} الخطوة ${item.title}',
                      onPressed: widget.saving
                          ? null
                          : () => widget.onRemove(item),
                      icon: const Icon(
                        LucideIcons.x,
                        size: 18,
                        color: AarastV3Color.textFaint,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AarastV3Space.x1),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: JourneyTextField(
                      key: const ValueKey('task-checklist-new-item'),
                      label: context.say('أضف خطوة', 'أضيفي خطوة'),
                      hint: context.say(
                        'مثلًا: كلّم القاعة',
                        'مثلًا: كلّمي الصالة',
                      ),
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x2),
                  JourneyRoundButton(
                    key: const ValueKey('task-checklist-add'),
                    icon: LucideIcons.plus,
                    tooltip: context.say('أضف الخطوة', 'أضيفي الخطوة'),
                    onPressed: widget.saving ? null : _add,
                  ),
                ],
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
          ),
        ),
      ],
    );
  }
}

/// Owns its text controller so it is disposed only after the sheet route,
/// including its closing animation, is gone.
class _RenameStepSheet extends StatefulWidget {
  const _RenameStepSheet({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameStepSheet> createState() => _RenameStepSheetState();
}

class _RenameStepSheetState extends State<_RenameStepSheet> {
  late final _controller = TextEditingController(text: widget.initialTitle);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return JourneySheetBody(
      title: 'تعديل الخطوة',
      children: [
        JourneyTextField(
          key: const ValueKey('task-checklist-rename-field'),
          label: 'الخطوة',
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        const SizedBox(height: AarastV3Space.x4),
        JourneyButton(
          key: const ValueKey('task-checklist-rename-save'),
          label: 'حفظ',
          background: context.accent.primary,
          expand: true,
          large: true,
          onPressed: () => Navigator.pop(context, _controller.text),
        ),
      ],
    );
  }
}
