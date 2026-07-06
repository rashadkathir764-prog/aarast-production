import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_plan.dart';

class PlanManagementView extends StatelessWidget {
  const PlanManagementView({
    required this.plan,
    required this.ownerName,
    required this.participantCount,
    required this.pendingInvites,
    required this.canManagePlan,
    required this.canManageSharing,
    required this.isLocalPlan,
    required this.onEditBasics,
    required this.onEditLocation,
    required this.onManageSharing,
    required this.onArchive,
    this.onBack,
    super.key,
  });

  final WeddingPlan plan;
  final String ownerName;
  final int? participantCount;
  final int pendingInvites;
  final bool canManagePlan;
  final bool canManageSharing;
  final bool isLocalPlan;
  final VoidCallback onEditBasics;
  final VoidCallback onEditLocation;
  final VoidCallback onManageSharing;
  final VoidCallback? onArchive;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final completeness = PlanDataCompleteness.fromPlan(plan);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 128),
      children: [
        _ManagementHeader(onBack: onBack),
        const SizedBox(height: 16),
        _PlanIdentityCard(plan: plan, isLocalPlan: isLocalPlan),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'بيانات الخطة',
          icon: LucideIcons.fileText,
          children: [
            _DataRow(label: 'اسم الخطة', value: plan.title),
            _DataRow(
              label: 'تاريخ الزواج',
              value: _dateLabel(plan.weddingDate),
            ),
            _DataRow(
              label: 'المدينة',
              value:
                  plan.weddingLocation.cityOrDistrict ??
                  plan.city ??
                  'غير محددة',
            ),
            _DataRow(label: 'الحالة', value: _statusLabel(plan.status)),
            _DataRow(label: 'العملة', value: currencyLabelAr(plan.currency)),
            if (canManagePlan) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('plan-edit-basics'),
                onPressed: onEditBasics,
                icon: const Icon(LucideIcons.pencil, size: 18),
                label: const Text('تعديل البيانات الأساسية'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _LocationSection(
          plan: plan,
          canManagePlan: canManagePlan,
          onEdit: onEditLocation,
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'المشاركون والصلاحيات',
          icon: LucideIcons.users,
          children: [
            _DataRow(label: 'صاحب الخطة', value: ownerName),
            _DataRow(
              label: 'عدد المشاركين',
              value: participantCount?.toString() ?? 'غير متاح',
            ),
            _DataRow(label: 'دعوات معلقة', value: pendingInvites.toString()),
            _DataRow(
              label: 'صلاحيتك',
              value: canManagePlan ? 'إدارة وتعديل' : 'عرض حسب الصلاحيات',
            ),
            if (canManageSharing) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('plan-manage-sharing'),
                onPressed: onManageSharing,
                icon: const Icon(LucideIcons.userCog, size: 18),
                label: const Text('إدارة المشاركين والصلاحيات'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _PreferencesSection(plan: plan),
        const SizedBox(height: 14),
        _CompletenessSection(plan: plan, completeness: completeness),
        if (!isLocalPlan && canManagePlan && onArchive != null) ...[
          const SizedBox(height: 18),
          _DangerSection(
            archived: plan.status.toUpperCase() == 'ARCHIVED',
            onArchive: onArchive!,
          ),
        ],
      ],
    );
  }
}

class PlanDataCompleteness {
  const PlanDataCompleteness({required this.percent, required this.missing});

  factory PlanDataCompleteness.fromPlan(WeddingPlan plan) {
    final checks = <String, bool>{
      'اسم الخطة': plan.title.trim().isNotEmpty,
      'تاريخ الزواج': plan.weddingDate != null,
      'الموقع': plan.weddingLocation.hasRequiredLocation,
      'العملة': plan.currency.trim().isNotEmpty,
      'الأولويات': plan.priorities.isNotEmpty,
    };
    final completed = checks.values.where((value) => value).length;
    return PlanDataCompleteness(
      percent: ((completed / checks.length) * 100).round(),
      missing: [
        for (final entry in checks.entries)
          if (!entry.value) entry.key,
      ],
    );
  }

  final int percent;
  final List<String> missing;
  bool get isComplete => missing.isEmpty;
}

class _ManagementHeader extends StatelessWidget {
  const _ManagementHeader({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          IconButton(
            onPressed: onBack,
            tooltip: 'رجوع',
            icon: const Icon(LucideIcons.arrowRight),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إدارة الخطة',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'إدارة بيانات ومشاركات خطة عرسك.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanIdentityCard extends StatelessWidget {
  const _PlanIdentityCard({required this.plan, required this.isLocalPlan});

  final WeddingPlan plan;
  final bool isLocalPlan;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AarastStatusPill(
                label: isLocalPlan ? 'محلية' : _statusLabel(plan.status),
                icon: isLocalPlan ? LucideIcons.smartphone : LucideIcons.check,
                color: isLocalPlan ? AppTheme.warning : AppTheme.success,
                backgroundColor: isLocalPlan
                    ? AppTheme.warningSoft
                    : AppTheme.successSoft,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _dateLabel(plan.weddingDate),
            style: const TextStyle(
              color: AppTheme.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            plan.weddingLocation.shortLabel ?? plan.city ?? 'المدينة غير محددة',
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({
    required this.plan,
    required this.canManagePlan,
    required this.onEdit,
  });

  final WeddingPlan plan;
  final bool canManagePlan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final location = plan.weddingLocation;
    return _SectionCard(
      title: 'موقع الزفاف',
      icon: LucideIcons.mapPin,
      children: [
        _DataRow(label: 'المحافظة', value: location.governorate ?? 'غير محددة'),
        _DataRow(
          label: 'المدينة / المديرية',
          value: location.cityOrDistrict ?? plan.city ?? 'غير محددة',
        ),
        _DataRow(
          label: 'الحي / المنطقة',
          value: location.areaOrNeighborhood ?? 'لم يضف بعد',
        ),
        _DataRow(label: 'الشارع', value: location.street ?? 'لم يضف بعد'),
        _DataRow(
          label: 'العنوان التفصيلي',
          value: location.detailedAddress ?? 'لم يضف بعد',
        ),
        if (canManagePlan) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('plan-edit-location'),
            onPressed: onEdit,
            icon: const Icon(LucideIcons.mapPin, size: 18),
            label: const Text('تعديل الموقع'),
          ),
        ],
      ],
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({required this.plan});

  final WeddingPlan plan;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'تفضيلات الخطة',
      icon: LucideIcons.slidersHorizontal,
      children: [
        _DataRow(label: 'مسار الخطة', value: _pathLabel(plan.onboardingPath)),
        _DataRow(label: 'صاحب المسار', value: _personaLabel(plan.persona)),
        _DataRow(label: 'العملة', value: currencyLabelAr(plan.currency)),
        const SizedBox(height: 8),
        const Text(
          'الأولويات',
          style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (plan.priorities.isEmpty)
          const Text(
            'لم تحدد أولويات الخطة بعد.',
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final priority in plan.priorities)
                Chip(label: Text(_priorityLabel(priority))),
            ],
          ),
      ],
    );
  }
}

class _CompletenessSection extends StatelessWidget {
  const _CompletenessSection({required this.plan, required this.completeness});

  final WeddingPlan plan;
  final PlanDataCompleteness completeness;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'حالة اكتمال البيانات',
      icon: LucideIcons.clipboardCheck,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                completeness.isComplete ? 'مكتملة' : 'بيانات ناقصة',
                style: TextStyle(
                  color: completeness.isComplete
                      ? AppTheme.success
                      : AppTheme.warning,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '${completeness.percent}%',
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: completeness.percent / 100,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
          color: completeness.isComplete ? AppTheme.success : AppTheme.warning,
          backgroundColor: AppTheme.border,
        ),
        if (!completeness.isComplete) ...[
          const SizedBox(height: 10),
          Text(
            'أكمل: ${completeness.missing.join('، ')}',
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: 10),
        _DataRow(label: 'آخر تحديث', value: _dateTimeLabel(plan.updatedAt)),
      ],
    );
  }
}

class _DangerSection extends StatelessWidget {
  const _DangerSection({required this.archived, required this.onArchive});

  final bool archived;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'أمان وإدارة الخطة',
      icon: LucideIcons.shieldAlert,
      borderColor: AppTheme.danger.withValues(alpha: 0.35),
      children: [
        Text(
          archived
              ? 'هذه الخطة مؤرشفة ولا يمكن تعيينها كخطة نشطة.'
              : 'الأرشفة توقف استخدام الخطة كخطة نشطة دون حذف بياناتها.',
          style: const TextStyle(
            color: AppTheme.muted,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
        if (!archived) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('plan-archive'),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
            onPressed: onArchive,
            icon: const Icon(LucideIcons.archive, size: 18),
            label: const Text('أرشفة الخطة'),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.borderColor,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      border: Border.all(color: borderColor ?? AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.burgundy, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String value) {
  return switch (value.toUpperCase()) {
    'ARCHIVED' => 'مؤرشفة',
    'COMPLETED' => 'مكتملة',
    _ => 'نشطة',
  };
}

String _pathLabel(String? value) {
  return switch (value?.toUpperCase()) {
    'PROVIDER' => 'مزوّد خدمات',
    'USER' => 'تخطيط زفاف',
    _ => 'غير محدد',
  };
}

String _personaLabel(String? value) {
  return switch (value?.toUpperCase()) {
    'GROOM' => 'العريس',
    'BRIDE' => 'العروس',
    'HELPER' => 'مساعد / منسق',
    _ => 'غير محدد',
  };
}

String _priorityLabel(String value) {
  return switch (value.toLowerCase()) {
    'budget' => 'الميزانية',
    'tasks' => 'المهام',
    'guests' => 'الضيوف',
    'providers' => 'الموردون',
    _ => value,
  };
}

String _dateLabel(DateTime? value) {
  if (value == null) return 'غير محدد';
  const weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return '${weekdays[value.weekday - 1]}، ${value.day} ${months[value.month - 1]} ${value.year}';
}

String _dateTimeLabel(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.day}/${value.month}/${value.year}، $hour:$minute';
}
