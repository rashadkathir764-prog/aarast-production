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

/// One place that may know a plan's persona: the selected account context,
/// a plan the plans provider loaded, or the guest draft before sign-in.
typedef TaskStarterPersonaSource = ({String? planId, String? persona});

/// The persona of [weddingPlanId] from the first source, in priority order,
/// that describes that plan and carries a persona. Neutral when none does.
TaskStarterPersona taskStarterPersonaFor(
  String weddingPlanId,
  Iterable<TaskStarterPersonaSource> sources,
) {
  for (final source in sources) {
    if (source.planId == weddingPlanId && source.persona != null) {
      return taskStarterPersonaFromCode(source.persona);
    }
  }
  return TaskStarterPersona.neutral;
}

class TaskStarterTemplate {
  const TaskStarterTemplate({
    required this.key,
    required this.title,
    required this.daysBefore,
    this.recommended = false,
    String? taskCategory,
  }) : _taskCategory = taskCategory;

  final String key;
  final String title;

  /// Days before the wedding the task should be done; null when unknown.
  final int? daysBefore;
  final bool recommended;
  final String? _taskCategory;

  /// The task category it is filed under; null is general.
  String? get taskCategory => _taskCategory ?? _starterTaskCategories[key];
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
            taskCategory: switch (item.metadata['taskCategory']) {
              final String value when value.trim().isNotEmpty => value.trim(),
              _ => null,
            },
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
/// never in the past. No wedding date or no offset leaves the task undated.
///
/// When the tasks being added need more lead time than is left
/// ([longestDaysBefore] is past today), the whole set is compressed into the
/// time that is left, keeping its order and spacing; otherwise a short
/// engagement would see every early task due today at once (field test Q05).
DateTime? taskStarterDueDate(
  DateTime? weddingDate,
  int? daysBefore,
  DateTime today, {
  int? longestDaysBefore,
}) {
  if (weddingDate == null || daysBefore == null) return null;
  final wedding = DateTime(
    weddingDate.year,
    weddingDate.month,
    weddingDate.day,
  );
  final todayDate = DateTime(today.year, today.month, today.day);
  final daysLeft = wedding.difference(todayDate).inDays;
  var lead = daysBefore;
  if (longestDaysBefore != null &&
      longestDaysBefore > daysLeft &&
      longestDaysBefore > 0 &&
      daysLeft > 0) {
    lead = (daysBefore * daysLeft / longestDaysBefore).round();
  }
  final due = wedding.subtract(Duration(days: lead));
  return due.isBefore(todayDate) ? todayDate : due;
}

/// The task category the built-in suggested tasks file under, so they do not
/// all land in the general bucket. A managed item may set its own in
/// `metadata.taskCategory`; an unknown key stays general.
const _starterTaskCategories = <String, String>{
  'task-shared-budget': 'MONEY',
  'task-shared-photo': 'PHOTOGRAPHY',
  'task-shared-guests': 'GUESTS',
  'task-shared-contract': 'DOCUMENTS',
  'task-shared-invites': 'GUESTS',
  'task-groom-mahr': 'MONEY',
  'task-groom-gold': 'MONEY',
  'task-groom-venue': 'VENUE',
  'task-groom-kiswa': 'ATTIRE',
  'task-groom-artist': 'PROVIDERS',
  'task-groom-food': 'CATERING',
  'task-groom-suit': 'ATTIRE',
  'task-groom-qat': 'CATERING',
  'task-groom-zaffa': 'PROVIDERS',
  'task-bride-hall': 'VENUE',
  'task-bride-dress': 'ATTIRE',
  'task-bride-coiffeur': 'PROVIDERS',
  'task-bride-singer': 'PROVIDERS',
  'task-bride-naqsh': 'PROVIDERS',
  'task-bride-subhia': 'CATERING',
  'task-family-stay': 'GUESTS',
  'task-family-hosting': 'CATERING',
  'task-family-helpers': 'GUESTS',
};

/// The suggested task that sets the wedding date; it is not offered to a plan
/// that already has one (field test Q06).
const taskStarterWeddingDateKey = 'task-shared-date';

/// Drops the templates a plan no longer needs: setting the wedding date when
/// the plan has one.
List<TaskStarterGroup> taskStarterGroupsForPlan(
  List<TaskStarterGroup> groups, {
  required bool hasWeddingDate,
}) {
  if (!hasWeddingDate) return groups;
  return [
    for (final group in groups)
      if (group.templates.any((item) => item.key != taskStarterWeddingDateKey))
        TaskStarterGroup(
          key: group.key,
          title: group.title,
          subtitle: group.subtitle,
          templates: [
            for (final item in group.templates)
              if (item.key != taskStarterWeddingDateKey) item,
          ],
        ),
  ];
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

/// How many starter tasks a new plan for [personaCode] is offered.
int taskStarterCountFor(ManagedReferenceCatalog? managed, String? personaCode) {
  return taskStarterGroupsFor(
    managed,
    taskStarterPersonaFromCode(personaCode),
  ).fold(0, (sum, group) => sum + group.templates.length);
}
