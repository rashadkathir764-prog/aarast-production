import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/plan_day.dart';
import '../models/wedding_task.dart';

/// عرض المهام — مصدر حقيقة واحد للألوان والتسميات والأيقونات،
/// يشترك فيه الشاشة والبطاقة الذكية.

DateTime taskDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// Late from the day after its due day, today counted in Sana'a (D11,
/// RA-MO-25), as the server counts it.
bool isTaskLate(WeddingTask task, {DateTime? now}) {
  final dueDate = task.dueDate;
  if (dueDate == null || task.isDone) return false;
  return daysUntilPlanDay(dueDate, now: now) < 0;
}

/// y14: a task about the fireworks, known by its title («الألعاب النارية»,
/// «ألعاب نارية», with or without hamza or the final ة). Nothing else marks
/// a fireworks task: no task category or catalog item names them.
bool isFireworksTask(WeddingTask task) {
  final title = task.title
      .replaceAll(RegExp(r'[\u064B-\u0652\u0640]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه');
  return RegExp('العاب (ال)?ناريه').hasMatch(title);
}

Color taskPriorityColor(String priority) {
  return switch (priority) {
    'LOW' => AppTheme.success,
    'MEDIUM' => AppTheme.focus,
    'HIGH' => AppTheme.danger,
    'URGENT' => AppTheme.danger,
    _ => AppTheme.textSecondary,
  };
}

String taskPriorityLabel(String priority) {
  return switch (priority) {
    'LOW' => 'منخفضة',
    'MEDIUM' => 'متوسطة',
    'HIGH' => 'عالية',
    'URGENT' => 'عاجلة',
    _ => priority,
  };
}

String taskStatusLabel(String status) {
  return switch (status) {
    'DONE' => 'مكتملة',
    'IN_PROGRESS' => 'قيد التنفيذ',
    'TODO' => 'لم تبدأ',
    'CANCELLED' => 'ملغية',
    _ => status,
  };
}

String taskCategoryLabel(String? category) {
  final value = category?.trim();
  // Same word the task form shows for the same value (field test Q05).
  if (value == null || value.isEmpty || value == 'GENERAL') return 'عامة';
  return switch (value) {
    'VENUE' => 'القاعة',
    'GUESTS' => 'الضيوف',
    'MONEY' => 'المال',
    'PROVIDERS' => 'المزودين',
    'ATTIRE' => 'الملابس',
    'PHOTOGRAPHY' => 'التصوير',
    'CATERING' => 'الضيافة',
    'DECOR' => 'الزينة',
    'DOCUMENTS' => 'المستندات',
    _ => value,
  };
}

IconData taskCategoryIcon(String? category) {
  final value = category?.trim();
  return switch (value) {
    'VENUE' => LucideIcons.building2,
    'GUESTS' => LucideIcons.users,
    'MONEY' => LucideIcons.wallet,
    'PROVIDERS' => LucideIcons.store,
    'ATTIRE' => LucideIcons.shirt,
    'PHOTOGRAPHY' => LucideIcons.camera,
    'CATERING' => LucideIcons.utensils,
    'DECOR' => LucideIcons.flower2,
    'DOCUMENTS' => LucideIcons.fileText,
    _ => LucideIcons.tag,
  };
}
