import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/plan_day.dart';
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

  /// Adds the chosen templates. Null closes the sheet; a reason keeps it
  /// open with the choice, and says why nothing was added.
  final Future<String?> Function(List<TaskStarterTemplate> templates) onSubmit;

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
  String? _failure;

  bool _exists(TaskStarterTemplate template) =>
      widget.existingTitles.contains(taskStarterTitleKey(template.title));

  List<TaskStarterTemplate> get _chosen => [
    for (final group in widget.groups)
      for (final template in group.templates)
        if (_selected.contains(template.key)) template,
  ];

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    final failure = await widget.onSubmit(_chosen);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failure = failure;
    });
    if (failure == null) Navigator.of(context).pop(true);
  }

  /// The day the task is saved with: the same rule as the save, so a short
  /// engagement shows the compressed days it will really get.
  String? _when(TaskStarterTemplate template) {
    final wedding = widget.weddingDate;
    if (wedding == null || template.daysBefore == null) return null;
    var longest = template.daysBefore!;
    for (final chosen in _chosen) {
      final days = chosen.daysBefore ?? 0;
      if (days > longest) longest = days;
    }
    final today = sanaaToday();
    final date = taskStarterDueDate(
      wedding,
      template.daysBefore,
      today,
      longestDaysBefore: longest,
    );
    if (date == null) return null;
    return date.isAtSameMomentAs(today) ? 'الآن' : formatArabicDayMonth(date);
  }

  @override
  Widget build(BuildContext context) {
    final count = _selected.length;
    return JourneySheetBody(
      title: 'مهام جاهزة لعرسك',
      subtitle: widget.hasWeddingDate
          ? context.say(
              'مرتبة على موعدك · شيل اللي ما يخصك',
              'مرتبة على موعدك · شيلي اللي ما يخصك',
            )
          : context.say(
              'شيل اللي ما يخصك · ثبّت موعد العرس وتترتب المواعيد',
              'شيلي اللي ما يخصك · ثبّتي موعد العرس وتترتب المواعيد',
            ),
      bottom: JourneyButton(
        key: const Key('task-starter-submit'),
        label: count == 0
            ? context.say(
                'اختر مهمة وحدة على الأقل',
                'اختاري مهمة وحدة على الأقل',
              )
            : '${context.say('أضف', 'أضيفي')} ${arabicCount(count, one: 'مهمة وحدة', two: 'مهمتين', few: 'مهام', many: 'مهمة')} لخطتي',
        icon: LucideIcons.listPlus,
        background: context.accent.primary,
        expand: true,
        large: true,
        loading: _saving,
        onPressed: count == 0 || _saving ? null : _submit,
      ),
      children: [
        if (_failure != null)
          Padding(
            padding: const EdgeInsets.only(top: AarastV3Space.x2),
            child: JourneyNote(
              key: const ValueKey('task-starter-failure'),
              text: _failure!,
              icon: LucideIcons.alertCircle,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
          ),
        for (final group in widget.groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x1,
              AarastV3Space.x3,
              AarastV3Space.x1,
              AarastV3Space.x2,
            ),
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
                const SizedBox(width: AarastV3Space.x2),
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
            padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
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
            padding: AarastV3Density.chipInsets,
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: on
                        ? (added
                              ? AarastV3Color.textFaint
                              : context.accent.primary)
                        : null,
                    borderRadius: BorderRadius.circular(AarastV3Radius.xs),
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
                const SizedBox(width: AarastV3Space.x3),
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
