import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/shared_member.dart';

/// صف عضو مدمج: أفاتار + اسم + ملخص صلاحيات في سطر واحد + شارة الدور.
/// تفاصيل الصلاحيات تُدار من شاشة التعديل — لا رقائق ولا جمل مكررة هنا.
class SharedMemberCard extends StatelessWidget {
  const SharedMemberCard({
    required this.member,
    required this.onTap,
    super.key,
  });

  final SharedMember member;
  final VoidCallback? onTap;

  String get _initial {
    final name = member.displayName.trim();
    return name.isEmpty ? 'ع' : name[0];
  }

  Color get _roleColor {
    if (member.isOwner) return AppTheme.burgundy;
    return member.hasFinancialAccess ? AppTheme.gold : AppTheme.muted;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final roleLabel = member.isOwner
        ? 'مالك الخطة'
        : sharedMemberRoleLabel(member.role);

    return AarastCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppTheme.burgundySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initial,
              style: textTheme.titleSmall?.copyWith(
                color: AppTheme.burgundy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (member.displayNamePhone case final phone?)
                  AarastPhoneText(
                    phone: phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  Text(
                    member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  member.permissionSummary,
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
          if (member.hasFinancialAccess) ...[
            Semantics(
              label: 'لديه وصول مالي',
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.wallet,
                  size: 12,
                  color: AppTheme.gold,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _roleColor.withAlpha(24),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              roleLabel,
              maxLines: 1,
              style: textTheme.labelSmall?.copyWith(
                color: _roleColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronLeft,
              size: 16,
              color: AppTheme.muted.withAlpha(180),
            ),
          ],
        ],
      ),
    );
  }
}
