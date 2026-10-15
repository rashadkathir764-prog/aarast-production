import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../models/wedding_task.dart';

/// عرض المهام — مصدر حقيقة واحد للألوان والتسميات والأيقونات،
/// يشترك فيه الشاشة والبطاقة الذكية.

DateTime taskDateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

bool isTaskLate(WeddingTask task, {DateTime? now}) {
  final dueDate = task.dueDate;
  if (dueDate == null || task.isDone) return false;
  return taskDateOnly(dueDate).isBefore(taskDateOnly(now ?? DateTime.now()));
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
    'PROVIDERS' => 'الموردين',
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

String taskRelativeDueLabel(DateTime date, {DateTime? now}) {
  final today = taskDateOnly(now ?? DateTime.now());
  final target = taskDateOnly(date);
  final diff = target.difference(today).inDays;
  if (diff < 0) return 'متأخر ${-diff} ${-diff == 1 ? 'يوم' : 'يوم'}';
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'غدًا';
  if (diff <= 7) return 'بعد $diff أيام';
  return formatArabicCompactDate(date);
}
