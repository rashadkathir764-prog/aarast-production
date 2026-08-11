import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
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
    if (member.isOwner) return AppTheme.brand;
    return member.hasFinancialAccess ? AppTheme.focus : AppTheme.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final roleLabel = member.isOwner
        ? 'مالك الخطة'
        : sharedMemberRoleLabel(member.role);
    final displayNamePhone = member.displayNamePhone;

    return AarastV3ListRow(
      title: member.displayName,
      titleWidget: displayNamePhone == null
          ? null
          : AarastPhoneText(
              phone: displayNamePhone,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
      subtitle: member.permissionSummary,
      accent: _roleColor,
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: AppTheme.brandMuted,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          _initial,
          style: textTheme.titleSmall?.copyWith(
            color: AppTheme.brand,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      status: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (member.hasFinancialAccess) ...[
            Semantics(
              label: 'لديه وصول مالي',
              child: const Icon(
                LucideIcons.wallet,
                size: 13,
                color: AppTheme.focus,
              ),
            ),
            const SizedBox(width: AarastV3Space.x1),
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
        ],
      ),
    );
  }
}
