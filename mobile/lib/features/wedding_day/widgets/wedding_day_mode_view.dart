import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_loading_state.dart';
import '../../tasks/tasks_api.dart' show WeddingTask;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardProviderPreview, DashboardSummary;
import '../models/wedding_day_mode.dart';

class WeddingDayModeView extends StatelessWidget {
  const WeddingDayModeView({
    required this.summary,
    required this.tasks,
    required this.onRefresh,
    required this.onCompleteTask,
    required this.onCopyPhone,
    required this.onOpenTasks,
    required this.onOpenGuests,
    required this.onOpenProviders,
    required this.onOpenProvider,
    this.isLoading = false,
    this.notice,
    this.now,
    super.key,
  });

  final DashboardSummary summary;
  final List<WeddingTask> tasks;
  final Future<void> Function() onRefresh;
  final ValueChanged<WeddingTask> onCompleteTask;
  final ValueChanged<String> onCopyPhone;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenProviders;
  final ValueChanged<DashboardProviderPreview> onOpenProvider;
  final bool isLoading;
  final String? notice;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final status = resolveWeddingDayMode(summary.weddingDate, now: now);
    final priorityTasks = weddingDayPriorityTasks(
      tasks: tasks,
      status: status,
      now: now,
    );
    final visibleTasks = priorityTasks.take(5).toList();
    final contacts = _contactsFromTasks(priorityTasks);
    final providers = summary.planProviders
        .where((provider) => provider.businessName.trim().isNotEmpty)
        .take(4)
        .toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const Key('wedding-day-mode-view'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AarastV3Space.x5,
          AarastV3Space.x3,
          AarastV3Space.x5,
          AarastV3Space.x10,
        ),
        children: [
          const OfflineStatusBanner(),
          if (notice?.trim().isNotEmpty == true) ...[
            _InlineNotice(message: notice!.trim()),
            const SizedBox(height: AarastV3Space.x3),
          ],
          _WeddingDayHeader(summary: summary, status: status),
          if (!status.isVisible) ...[
            const SizedBox(height: AarastV3Space.x5),
            const _UnavailableMessage(),
          ] else ...[
            const SizedBox(height: AarastV3Space.x5),
            _SectionHeading(
              icon: LucideIcons.zap,
              title: status.phase == WeddingDayPhase.countdown
                  ? 'ما يلزم قبل يومكم'
                  : 'ما يحتاجك الآن',
              trailing: priorityTasks.length > visibleTasks.length
                  ? '${priorityTasks.length} مهام'
                  : null,
            ),
            const SizedBox(height: AarastV3Space.x2),
            if (isLoading && tasks.isEmpty)
              const AarastLoadingState(rows: 2, height: 74)
            else if (visibleTasks.isEmpty)
              const _CalmEmpty(
                icon: LucideIcons.badgeCheck,
                title: 'لا توجد مهمة حرجة الآن',
                message: 'خطتكم هادئة؛ ستظهر هنا المهام المستحقة فقط.',
              )
            else
              AarastV3ContinuousSurface(
                children: [
                  for (final task in visibleTasks)
                    _WeddingDayTaskRow(
                      task: task,
                      now: now,
                      onComplete: () => onCompleteTask(task),
                    ),
                ],
              ),
            if (priorityTasks.length > visibleTasks.length) ...[
              const SizedBox(height: AarastV3Space.x2),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: onOpenTasks,
                  icon: const Icon(LucideIcons.listChecks, size: 18),
                  label: const Text('عرض كل المهام'),
                ),
              ),
            ],
            if (contacts.isNotEmpty) ...[
              const SizedBox(height: AarastV3Space.x6),
              const _SectionHeading(
                icon: LucideIcons.contact,
                title: 'المسؤولون المهمون',
                trailing: 'اضغط لنسخ الرقم',
              ),
              const SizedBox(height: AarastV3Space.x2),
              AarastV3ContinuousSurface(
                children: [
                  for (final contact in contacts.take(4))
                    AarastV3ListRow(
                      title: contact.name,
                      subtitle: contact.phone,
                      meta: contact.taskTitle,
                      leading: const Icon(
                        LucideIcons.phone,
                        color: AarastV3Color.primary,
                        size: 19,
                      ),
                      action: IconButton(
                        tooltip: 'نسخ رقم ${contact.name}',
                        onPressed: () => onCopyPhone(contact.phone),
                        icon: const Icon(LucideIcons.copy, size: 18),
                      ),
                    ),
                ],
              ),
            ],
            if (providers.isNotEmpty) ...[
              const SizedBox(height: AarastV3Space.x6),
              const _SectionHeading(
                icon: LucideIcons.store,
                title: 'مزوّدو الخطة',
              ),
              const SizedBox(height: AarastV3Space.x2),
              AarastV3ContinuousSurface(
                children: [
                  for (final provider in providers)
                    AarastV3ListRow(
                      title: provider.businessName,
                      subtitle: provider.serviceTitle ?? provider.categoryName,
                      leading: const Icon(
                        LucideIcons.store,
                        color: AarastV3Color.primary,
                        size: 19,
                      ),
                      onTap: provider.providerId.trim().isEmpty
                          ? null
                          : () => onOpenProvider(provider),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AarastV3Space.x6),
            const _SectionHeading(
              icon: LucideIcons.layoutGrid,
              title: 'الوصول السريع',
            ),
            const SizedBox(height: AarastV3Space.x2),
            AarastV3ContinuousSurface(
              children: [
                AarastV3ListRow(
                  title: 'كل المهام',
                  subtitle: 'راجع الجدول أو أعد ترتيب ما تبقّى.',
                  leading: const Icon(LucideIcons.listChecks),
                  onTap: onOpenTasks,
                ),
                AarastV3ListRow(
                  title: 'الضيوف',
                  subtitle: 'راجع الردود والمقاعد عند الحاجة.',
                  leading: const Icon(LucideIcons.users),
                  onTap: onOpenGuests,
                ),
                AarastV3ListRow(
                  title: 'المزوّدون',
                  subtitle: 'افتح المزوّد المطلوب دون بحث طويل.',
                  leading: const Icon(LucideIcons.store),
                  onTap: onOpenProviders,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeddingDayHeader extends StatelessWidget {
  const _WeddingDayHeader({required this.summary, required this.status});

  final DashboardSummary summary;
  final WeddingDayModeStatus status;

  @override
  Widget build(BuildContext context) {
    final date = summary.weddingDate;
    final location = _locationLabel(summary);
    final hasTime = date != null && (date.hour != 0 || date.minute != 0);
    return Container(
      padding: const EdgeInsets.all(AarastV3Space.x4),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
        border: Border.all(color: AarastV3Color.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AarastV3Color.primarySoft,
                  borderRadius: BorderRadius.circular(AarastV3Radius.surface),
                  border: Border.all(color: AarastV3Color.lineStrong),
                ),
                child: Text(
                  weddingPlanMonogram(summary.title),
                  style: AarastV3Type.section(
                    context,
                  ).copyWith(color: AarastV3Color.primary),
                ),
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.eyebrow,
                      style: AarastV3Type.label(
                        context,
                      ).copyWith(color: AarastV3Color.primary),
                    ),
                    const SizedBox(height: AarastV3Space.x1),
                    Text(
                      status.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AarastV3Type.section(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x3),
          if (date != null)
            _HeaderDetail(
              icon: LucideIcons.calendarDays,
              label: formatArabicDate(date),
            ),
          if (hasTime) ...[
            const SizedBox(height: AarastV3Space.x2),
            _HeaderDetail(icon: LucideIcons.clock3, label: _formatTime(date)),
          ],
          if (location != null) ...[
            const SizedBox(height: AarastV3Space.x2),
            _HeaderDetail(icon: LucideIcons.mapPin, label: location),
          ],
        ],
      ),
    );
  }
}

class _HeaderDetail extends StatelessWidget {
  const _HeaderDetail({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AarastV3Color.textMuted),
        const SizedBox(width: AarastV3Space.x2),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AarastV3Type.body(context),
          ),
        ),
      ],
    );
  }
}

class _WeddingDayTaskRow extends StatelessWidget {
  const _WeddingDayTaskRow({
    required this.task,
    required this.onComplete,
    this.now,
  });

  final WeddingTask task;
  final VoidCallback onComplete;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return AarastV3ListRow(
      title: task.title,
      subtitle: task.responsiblePhoneDisplay == null
          ? 'المسؤول: ${task.directionalResponsibleLabel}'
          : 'المسؤول: ${task.directionalResponsibleLabel} · ${task.responsiblePhoneDisplay}',
      meta: _taskDueLabel(task.dueDate, now: now),
      accent: _taskAccent(task.dueDate, now: now),
      leading: IconButton(
        tooltip: 'إنجاز ${task.title}',
        onPressed: onComplete,
        style: IconButton.styleFrom(
          minimumSize: const Size(42, 42),
          side: const BorderSide(color: AarastV3Color.lineStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AarastV3Radius.control),
          ),
        ),
        icon: const Icon(LucideIcons.check, size: 19),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AarastV3Color.primary),
        const SizedBox(width: AarastV3Space.x2),
        Expanded(child: Text(title, style: AarastV3Type.section(context))),
        if (trailing != null)
          Text(
            trailing!,
            style: AarastV3Type.label(
              context,
            ).copyWith(color: AarastV3Color.textMuted),
          ),
      ],
    );
  }
}

class _CalmEmpty extends StatelessWidget {
  const _CalmEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AarastV3Space.x4),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AarastV3Color.line),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AarastV3Color.mint, size: 21),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AarastV3Type.section(context)),
                const SizedBox(height: AarastV3Space.x1),
                Text(message, style: AarastV3Type.body(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnavailableMessage extends StatelessWidget {
  const _UnavailableMessage();

  @override
  Widget build(BuildContext context) {
    return const _CalmEmpty(
      icon: LucideIcons.calendarClock,
      title: 'سيظهر في الوقت الصحيح',
      message:
          'يفتح هذا الوضع قبل العرس بسبعة أيام، ليعرض فقط ما يحتاج انتباهك في ذلك الوقت.',
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AarastV3Space.x3),
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x3,
        vertical: AarastV3Space.x2,
      ),
      decoration: const BoxDecoration(
        color: AarastV3Color.paper,
        border: BorderDirectional(
          start: BorderSide(color: AarastV3Color.amber, width: 3),
        ),
      ),
      child: Text(message, style: AarastV3Type.body(context)),
    );
  }
}

class _WeddingDayContact {
  const _WeddingDayContact({
    required this.name,
    required this.phone,
    required this.taskTitle,
  });

  final String name;
  final String phone;
  final String taskTitle;
}

List<_WeddingDayContact> _contactsFromTasks(List<WeddingTask> tasks) {
  final contacts = <_WeddingDayContact>[];
  final phones = <String>{};
  for (final task in tasks) {
    final phone = task.responsiblePhoneDisplay?.trim();
    if (phone == null || phone.isEmpty || !phones.add(phone)) continue;
    contacts.add(
      _WeddingDayContact(
        name: task.directionalResponsibleLabel,
        phone: phone,
        taskTitle: task.title,
      ),
    );
  }
  return contacts;
}

String? _locationLabel(DashboardSummary summary) {
  final fullLabel = summary.location?['fullLabel']?.toString().trim();
  if (fullLabel?.isNotEmpty == true) return fullLabel;
  final address = summary.location?['address']?.toString().trim();
  if (address?.isNotEmpty == true) return address;
  final city = summary.city?.trim();
  return city?.isNotEmpty == true ? city : null;
}

String _formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'ص' : 'م';
  return '$hour:$minute $period';
}

String _taskDueLabel(DateTime? dueDate, {DateTime? now}) {
  if (dueDate == null) return 'أولوية عالية دون موعد';
  final today = _dateOnly(now ?? DateTime.now());
  final due = _dateOnly(dueDate);
  final difference = due.difference(today).inDays;
  return switch (difference) {
    < 0 => 'متأخرة ${difference.abs()} يوم',
    0 => 'اليوم',
    1 => 'غدًا',
    _ => formatArabicCompactDate(dueDate),
  };
}

Color _taskAccent(DateTime? dueDate, {DateTime? now}) {
  if (dueDate == null) return AarastV3Color.amber;
  final today = _dateOnly(now ?? DateTime.now());
  final due = _dateOnly(dueDate);
  if (due.isBefore(today)) return AarastV3Color.rose;
  if (due == today) return AarastV3Color.signal;
  return AarastV3Color.primary;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
