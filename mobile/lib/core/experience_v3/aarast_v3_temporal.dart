import '../utils/app_clock.dart';

enum AarastTemporalSection { now, today, week, later, completed }

extension AarastTemporalSectionLabel on AarastTemporalSection {
  String get label => switch (this) {
    AarastTemporalSection.now => 'الآن',
    AarastTemporalSection.today => 'اليوم',
    AarastTemporalSection.week => 'هذا الأسبوع',
    AarastTemporalSection.later => 'لاحقًا',
    AarastTemporalSection.completed => 'مكتمل',
  };
}

AarastTemporalSection aarastDeadlineSection({
  required DateTime? dueDate,
  required bool completed,
  DateTime? now,
}) {
  if (completed) return AarastTemporalSection.completed;
  if (dueDate == null) return AarastTemporalSection.later;
  final today = aarastDateOnly(now ?? appNow());
  final due = aarastDateOnly(dueDate);
  if (due.isBefore(today)) return AarastTemporalSection.now;
  if (due == today) return AarastTemporalSection.today;
  if (due.isBefore(today.add(const Duration(days: 8)))) {
    return AarastTemporalSection.week;
  }
  return AarastTemporalSection.later;
}

AarastTemporalSection aarastActivitySection({
  required DateTime occurredAt,
  required bool completed,
  bool urgent = false,
  DateTime? now,
}) {
  if (completed) return AarastTemporalSection.completed;
  final current = now ?? appNow();
  if (urgent ||
      (!occurredAt.isAfter(current) &&
          current.difference(occurredAt) <= const Duration(hours: 2))) {
    return AarastTemporalSection.now;
  }
  final today = aarastDateOnly(current);
  final occurred = aarastDateOnly(occurredAt);
  if (occurred == today) return AarastTemporalSection.today;
  if (!occurred.isBefore(today.subtract(const Duration(days: 6)))) {
    return AarastTemporalSection.week;
  }
  return AarastTemporalSection.later;
}

Map<AarastTemporalSection, List<T>> aarastTemporalGroups<T>(
  Iterable<T> items,
  AarastTemporalSection Function(T item) resolve,
) {
  final groups = <AarastTemporalSection, List<T>>{
    for (final section in AarastTemporalSection.values) section: <T>[],
  };
  for (final item in items) {
    groups[resolve(item)]!.add(item);
  }
  groups.removeWhere((_, values) => values.isEmpty);
  return groups;
}

DateTime aarastDateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
