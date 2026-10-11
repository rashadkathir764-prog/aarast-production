import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/task_starter_catalog.dart';

/// Suggested tasks to start a plan with: the recommended ones are chosen,
/// tasks the plan already has are shown as added, and the due dates follow
/// the wedding date when there is one.
class TaskStarterSheet extends StatefulWidget {
  const TaskStarterSheet({
    required this.groups,
    required this.existingTitles,
    required this.hasWeddingDate,
    required this.onSubmit,
    super.key,
  });

  final List<TaskStarterGroup> groups;

  /// [taskStarterTitleKey]s of the plan's tasks.
  final Set<String> existingTitles;
  final bool hasWeddingDate;

  /// Adds the chosen templates; returns whether the sheet can close.
  final Future<bool> Function(List<TaskStarterTemplate> templates) onSubmit;

  @override
  State<TaskStarterSheet> createState() => _TaskStarterSheetState();
}

class _TaskStarterSheetState extends State<TaskStarterSheet> {
  late final Set<String> _selected = {
    for (final group in widget.groups)
      for (final template in group.templates)
        if (template.recommended && !_exists(template)) template.key,
  };
  bool _saving = false;

  bool _exists(TaskStarterTemplate template) =>
      widget.existingTitles.contains(taskStarterTitleKey(template.title));

  List<TaskStarterTemplate> get _chosen => [
    for (final group in widget.groups)
      for (final template in group.templates)
        if (_selected.contains(template.key)) template,
  ];

  Future<void> _submit() async {
    setState(() => _saving = true);
    final close = await widget.onSubmit(_chosen);
    if (!mounted) return;
    setState(() => _saving = false);
    if (close) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مهام مقترحة لعرسك',
                      style: AarastV3Type.title(context),
                    ),
                    const SizedBox(height: AarastV3Space.x1),
                    Text(
                      widget.hasWeddingDate
                          ? 'اخترنا الأهم. تُرتب المواعيد تلقائيًا حسب موعد العرس، ويمكنك تعديل أي مهمة لاحقًا.'
                          : 'اخترنا الأهم. حدّد موعد العرس في الخطة لتُرتب المواعيد تلقائيًا.',
                      style: AarastV3Type.body(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  children: [
                    for (final group in widget.groups) ...[
                      Text(group.title, style: AarastV3Type.section(context)),
                      const SizedBox(height: AarastV3Space.x1),
                      Text(group.subtitle, style: AarastV3Type.body(context)),
                      const SizedBox(height: AarastV3Space.x2),
                      AarastV3ContinuousSurface(
                        children: [
                          for (final template in group.templates)
                            _TemplateRow(
                              template: template,
                              added: _exists(template),
                              selected: _selected.contains(template.key),
                              enabled: !_saving,
                              onTap: () => setState(() {
                                if (!_selected.remove(template.key)) {
                                  _selected.add(template.key);
                                }
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: AarastV3Space.x4),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: AarastButton(
                  key: const Key('task-starter-submit'),
                  label: count == 0
                      ? 'اختر مهمة واحدة على الأقل'
                      : 'إضافة $count إلى خطتي',
                  icon: LucideIcons.listPlus,
                  isLoading: _saving,
                  onPressed: count == 0 || _saving ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.added,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final TaskStarterTemplate template;
  final bool added;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !added,
      checked: added || selected,
      enabled: enabled && !added,
      label: template.title,
      child: InkWell(
        key: ValueKey('task-starter-${template.key}'),
        onTap: enabled && !added ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AarastV3Space.x3,
              vertical: AarastV3Space.x2,
            ),
            child: Row(
              children: [
                Icon(
                  added || selected
                      ? LucideIcons.checkCircle2
                      : LucideIcons.circle,
                  size: 20,
                  color: added
                      ? AppTheme.textSecondary
                      : selected
                      ? AppTheme.brand
                      : AppTheme.border,
                ),
                const SizedBox(width: AarastV3Space.x3),
                Expanded(
                  child: Text(
                    template.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: added
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (added)
                  Text(
                    'في خطتك',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
