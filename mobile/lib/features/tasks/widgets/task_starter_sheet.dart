import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/task_starter_catalog.dart';

/// d03 «مهام جاهزة لعرسك»: the recommended tasks are chosen, tasks the plan
/// already has show as added, and with a wedding date each one shows its
/// day. The button counts what will really be added (C6).
class TaskStarterSheet extends StatefulWidget {
  const TaskStarterSheet({
    required this.groups,
    required this.existingTitles,
    required this.hasWeddingDate,
    required this.onSubmit,
    this.weddingDate,
    super.key,
  });

  final List<TaskStarterGroup> groups;

  /// [taskStarterTitleKey]s of the plan's tasks.
  final Set<String> existingTitles;
  final bool hasWeddingDate;

  /// Shows each task's day; null shows none.
  final DateTime? weddingDate;

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

  String? _when(TaskStarterTemplate template) {
    final wedding = widget.weddingDate;
    final days = template.daysBefore;
    if (wedding == null || days == null) return null;
    final date = DateUtils.dateOnly(wedding).subtract(Duration(days: days));
    final today = DateUtils.dateOnly(DateTime.now());
    return date.isBefore(today) ? 'الآن' : formatArabicDayMonth(date);
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'مهام جاهزة لعرسك',
                    style: JourneyType.of(
                      JourneyType.title,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                Text(
                  widget.hasWeddingDate
                      ? 'مرتبة على موعدك · شيل اللي ما يخصك'
                      : 'شيل اللي ما يخصك · ثبّت موعد العرس وتترتب المواعيد',
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              children: [
                for (final group in widget.groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.title,
                            style: JourneyType.of(
                              JourneyType.bodyLarge,
                              weight: JourneyType.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            group.subtitle,
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  JourneyBox(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final template in group.templates)
                          _TemplateRow(
                            template: template,
                            when: _when(template),
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
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: JourneyButton(
              key: const Key('task-starter-submit'),
              label: count == 0
                  ? 'اختر مهمة وحدة على الأقل'
                  : 'أضف ${arabicCount(count, one: 'مهمة وحدة', two: 'مهمتين', few: 'مهام', many: 'مهمة')} لخطتي',
              icon: LucideIcons.listPlus,
              background: AarastV3Color.brandAccentStrong,
              expand: true,
              large: true,
              loading: _saving,
              onPressed: count == 0 || _saving ? null : _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.when,
    required this.added,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final TaskStarterTemplate template;
  final String? when;
  final bool added;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = added || selected;
    return Semantics(
      button: !added,
      checked: on,
      enabled: enabled && !added,
      label: template.title,
      excludeSemantics: true,
      child: AarastPressable(
        key: ValueKey('task-starter-${template.key}'),
        onTap: enabled && !added ? onTap : () {},
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: on
                        ? (added
                              ? AarastV3Color.textFaint
                              : AarastV3Color.brandAccentStrong)
                        : null,
                    borderRadius: BorderRadius.circular(7),
                    border: on
                        ? null
                        : Border.all(color: AarastV3Color.lineStrong, width: 2),
                  ),
                  child: on
                      ? const Icon(
                          LucideIcons.check,
                          size: 14,
                          color: AarastV3Color.onPrimary,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    template.title,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                      color: selected && !added
                          ? AarastV3Color.ink
                          : AarastV3Color.textMuted,
                    ),
                  ),
                ),
                if (added)
                  Text(
                    'في خطتك',
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: JourneyType.bold,
                      color: AarastV3Color.textMuted,
                    ),
                  )
                else if (when != null)
                  Text(
                    when!,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
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
