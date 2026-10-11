import '../../catalogs/catalogs_api.dart' show ManagedReferenceCatalog;

/// The managed catalog of suggested tasks (`tasks.starter` on the server).
const taskStarterCatalogKey = 'tasks.starter';

enum TaskStarterPersona { groom, bride, neutral }

TaskStarterPersona taskStarterPersonaFromCode(String? value) {
  return switch (value?.trim().toUpperCase()) {
    'GROOM' => TaskStarterPersona.groom,
    'BRIDE' => TaskStarterPersona.bride,
    _ => TaskStarterPersona.neutral,
  };
}

class TaskStarterTemplate {
  const TaskStarterTemplate({
    required this.key,
    required this.title,
    required this.daysBefore,
    this.recommended = false,
  });

  final String key;
  final String title;

  /// Days before the wedding the task should be done; null when unknown.
  final int? daysBefore;
  final bool recommended;
}

class TaskStarterGroup {
  const TaskStarterGroup({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.templates,
  });

  final String key;
  final String title;
  final String subtitle;
  final List<TaskStarterTemplate> templates;
}

/// The groups offered to [persona]: the groom sees his and the shared and
/// family tasks, the bride hers and the shared and family ones, and a plan
/// without a persona sees everything. The managed catalog wins; the built-in
/// copy covers a device that never loaded it.
List<TaskStarterGroup> taskStarterGroupsFor(
  ManagedReferenceCatalog? managed,
  TaskStarterPersona persona,
) {
  final items = managed?.items
      .where((item) {
        if (!item.showForCustomer) return false;
        return switch (persona) {
          TaskStarterPersona.groom => item.showForGroom,
          TaskStarterPersona.bride => item.showForBride,
          TaskStarterPersona.neutral => true,
        };
      })
      .toList(growable: false);
  if (items == null || items.isEmpty) {
    return [
      for (final group in _fallbackGroups)
        if (_fallbackVisible(group.key, persona)) group,
    ];
  }
  items.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  final grouped = <String, List<TaskStarterTemplate>>{};
  final titles = <String, (String, String)>{};
  for (final item in items) {
    final key = item.groupKey ?? 'other';
    titles.putIfAbsent(
      key,
      () => (
        item.groupNameAr ?? 'مهام إضافية',
        item.groupSubtitleAr ?? 'اختر ما يناسب خطتك.',
      ),
    );
    grouped
        .putIfAbsent(key, () => [])
        .add(
          TaskStarterTemplate(
            key: item.key,
            title: item.nameAr,
            daysBefore: int.tryParse('${item.metadata['daysBefore'] ?? ''}'),
            recommended: item.isRecommended,
          ),
        );
  }
  return [
    for (final entry in grouped.entries)
      TaskStarterGroup(
        key: entry.key,
        title: titles[entry.key]!.$1,
        subtitle: titles[entry.key]!.$2,
        templates: entry.value,
      ),
  ];
}

/// The due date: [TaskStarterTemplate.daysBefore] days before the wedding,
/// never in the past (a late plan still sees the task as due now). No
/// wedding date or no offset leaves the task undated.
DateTime? taskStarterDueDate(
  DateTime? weddingDate,
  int? daysBefore,
  DateTime today,
) {
  if (weddingDate == null || daysBefore == null) return null;
  final wedding = DateTime(
    weddingDate.year,
    weddingDate.month,
    weddingDate.day,
  );
  final due = wedding.subtract(Duration(days: daysBefore));
  final todayDate = DateTime(today.year, today.month, today.day);
  return due.isBefore(todayDate) ? todayDate : due;
}

/// Normalized task titles, so a template is not added twice to a plan.
String taskStarterTitleKey(String title) =>
    title.trim().replaceAll(RegExp(r'\s+'), ' ');

bool _fallbackVisible(String groupKey, TaskStarterPersona persona) {
  return switch (persona) {
    TaskStarterPersona.groom => groupKey != 'bride-tasks',
    TaskStarterPersona.bride => groupKey != 'groom-tasks',
    TaskStarterPersona.neutral => true,
  };
}

// The same defaults the server seeds (reference-catalog.defaults.ts).
const _fallbackGroups = [
  TaskStarterGroup(
    key: 'shared-tasks',
    title: 'مهام مشتركة',
    subtitle: 'الأساسيات التي يتفق عليها الطرفان.',
    templates: [
      TaskStarterTemplate(
        key: 'task-shared-date',
        title: 'تحديد موعد العرس',
        daysBefore: 300,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-shared-budget',
        title: 'تحديد الميزانية وتوزيعها على البنود',
        daysBefore: 300,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-shared-photo',
        title: 'حجز المصور',
        daysBefore: 120,
      ),
      TaskStarterTemplate(
        key: 'task-shared-home',
        title: 'تجهيز الشقة والأثاث',
        daysBefore: 120,
      ),
      TaskStarterTemplate(
        key: 'task-shared-guests',
        title: 'إعداد قائمة المعازيم',
        daysBefore: 90,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-shared-contract',
        title: 'تجهيز أوراق عقد القران',
        daysBefore: 60,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-shared-honeymoon',
        title: 'ترتيب شهر العسل',
        daysBefore: 60,
      ),
      TaskStarterTemplate(
        key: 'task-shared-invites',
        title: 'توزيع الدعوات',
        daysBefore: 30,
        recommended: true,
      ),
    ],
  ),
  TaskStarterGroup(
    key: 'groom-tasks',
    title: 'مهام العريس',
    subtitle: 'الاتفاقات ومناسبة الرجال.',
    templates: [
      TaskStarterTemplate(
        key: 'task-groom-mahr',
        title: 'الاتفاق مع أهل العروسة على المهر والشرط',
        daysBefore: 270,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-groom-gold',
        title: 'شراء الشبكة والذهب',
        daysBefore: 180,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-groom-venue',
        title: 'حجز قاعة أو مخدرة الرجال',
        daysBefore: 180,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-groom-kiswa',
        title: 'تجهيز الكسوة',
        daysBefore: 120,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-groom-artist',
        title: 'الاتفاق مع الفنان والفرقة',
        daysBefore: 120,
      ),
      TaskStarterTemplate(
        key: 'task-groom-food',
        title: 'الاتفاق على الوليمة والذبائح',
        daysBefore: 60,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-groom-suit',
        title: 'تفصيل ملابس العريس',
        daysBefore: 60,
      ),
      TaskStarterTemplate(
        key: 'task-groom-qat',
        title: 'ترتيب القات والمقيل',
        daysBefore: 14,
      ),
      TaskStarterTemplate(
        key: 'task-groom-zaffa',
        title: 'ترتيب الزفة والسيارة',
        daysBefore: 14,
      ),
    ],
  ),
  TaskStarterGroup(
    key: 'bride-tasks',
    title: 'مهام العروسة',
    subtitle: 'التجهيز ومناسبة النساء.',
    templates: [
      TaskStarterTemplate(
        key: 'task-bride-hall',
        title: 'حجز قاعة النساء',
        daysBefore: 180,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-bride-dress',
        title: 'اختيار فستان الزفاف',
        daysBefore: 150,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-bride-coiffeur',
        title: 'حجز الكوافير',
        daysBefore: 90,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-bride-singer',
        title: 'الاتفاق مع الفنانة أو الزفافة',
        daysBefore: 90,
      ),
      TaskStarterTemplate(
        key: 'task-bride-naqsh',
        title: 'حجز النقاشة لليلة النقش والحناء',
        daysBefore: 60,
        recommended: true,
      ),
      TaskStarterTemplate(
        key: 'task-bride-subhia',
        title: 'تجهيز الصبحية',
        daysBefore: 14,
      ),
    ],
  ),
  TaskStarterGroup(
    key: 'family-tasks',
    title: 'مهام الأهل',
    subtitle: 'ما يساعد فيه الأهل والأقارب.',
    templates: [
      TaskStarterTemplate(
        key: 'task-family-stay',
        title: 'ترتيب إقامة الضيوف القادمين من خارج المدينة',
        daysBefore: 30,
      ),
      TaskStarterTemplate(
        key: 'task-family-hosting',
        title: 'تجهيز استقبال الضيوف والضيافة',
        daysBefore: 14,
      ),
      TaskStarterTemplate(
        key: 'task-family-helpers',
        title: 'توزيع مهام يوم العرس على الأقارب',
        daysBefore: 7,
      ),
    ],
  ),
];
