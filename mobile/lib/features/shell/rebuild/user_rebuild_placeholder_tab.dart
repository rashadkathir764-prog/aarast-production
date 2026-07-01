import 'package:flutter/material.dart';

import 'user_rebuild_tab.dart';

class UserRebuildPlaceholderTab extends StatelessWidget {
  const UserRebuildPlaceholderTab({
    super.key,
    required this.tab,
    required this.message,
    required this.upcomingAreas,
  });

  factory UserRebuildPlaceholderTab.fromTab(UserRebuildTab tab) {
    return switch (tab) {
      UserRebuildTab.home => UserRebuildPlaceholderTab(
        tab: tab,
        message:
            'تبويب الرئيسية الداخلي — سيعرض مركز اليوم عند توفر مصدر الخطة الحالي',
        upcomingAreas: const [
          'ملخص الخطة الحالية',
          'أقرب المهام',
          'حالة المزامنة',
        ],
      ),
      UserRebuildTab.tasks => UserRebuildPlaceholderTab(
        tab: tab,
        message:
            'تبويب المهام الداخلي — يحتاج خطة حالية قبل عرض المهام والمواعيد',
        upcomingAreas: const [
          'المهام القادمة',
          'المواعيد المهمة',
          'حالة الإسناد',
        ],
      ),
      UserRebuildTab.providers => UserRebuildPlaceholderTab(
        tab: tab,
        message:
            'تبويب الموردون الداخلي — يعرض لاحقاً مراجع الموردين وطلبات العروض بدون حجوزات أو مدفوعات',
        upcomingAreas: const [
          'مراجع الموردين',
          'طلبات العروض',
          'مقارنات داخلية',
        ],
      ),
      UserRebuildTab.more => UserRebuildPlaceholderTab(
        tab: tab,
        message:
            'تبويب المزيد الداخلي — سيجمع الخطط والإعدادات والدعم بدون تغيير المسارات الحالية',
        upcomingAreas: const ['الخطط', 'الإعدادات', 'الدعم'],
      ),
      UserRebuildTab.money => UserRebuildPlaceholderTab(
        tab: tab,
        message: 'تبويب المال الداخلي مرتبط بواجهة داخلية منفصلة',
        upcomingAreas: const ['الميزانية', 'المصروفات', 'الديون'],
      ),
    };
  }

  final UserRebuildTab tab;
  final String message;
  final List<String> upcomingAreas;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(tab.icon, size: 44),
                const SizedBox(height: 12),
                Text(
                  tab.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: upcomingAreas
                      .map((area) => _UpcomingAreaChip(area))
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingAreaChip extends StatelessWidget {
  const _UpcomingAreaChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
