import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/shared_member.dart';
import '../models/shared_wedding_plan.dart';

/// صف خطة مشتركة مدمج: العنوان + سطر تفاصيل + ملخص صلاحياتك في سطر —
/// بدل كرت الرقائق القديم متعدد الأسطر.
class SharedPlanCard extends StatelessWidget {
  const SharedPlanCard({required this.plan, required this.onTap, super.key});

  final SharedWeddingPlan plan;
  final VoidCallback onTap;

  String get _detailsLine {
    final city = plan.city?.trim();
    final parts = <String>[
      if (city != null && city.isNotEmpty) city,
      if (plan.weddingDate != null) formatArabicCompactDate(plan.weddingDate!),
      currencyLabelAr(plan.currency),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final member = plan.sharedMember;
    final isArchived = plan.status == 'ARCHIVED';
    final roleColor = member.hasFinancialAccess
        ? AppTheme.gold
        : AppTheme.muted;

    return AarastCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.goldSoft.withAlpha(120),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              LucideIcons.calendarHeart,
              color: AppTheme.gold,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _detailsLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'صلاحياتك: ${member.toPermissions().summaryLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: roleColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  sharedMemberRoleLabel(member.role),
                  maxLines: 1,
                  style: textTheme.labelSmall?.copyWith(
                    color: roleColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isArchived) ...[
                const SizedBox(height: 4),
                Text(
                  'مؤرشفة',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
          Icon(
            LucideIcons.chevronLeft,
            size: 16,
            color: AppTheme.muted.withAlpha(180),
          ),
        ],
      ),
    );
  }
}
