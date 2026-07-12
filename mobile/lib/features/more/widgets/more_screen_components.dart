import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../onboarding/models/guest_onboarding_draft.dart';
import '../../onboarding/models/persona_copy.dart';
import '../../wedding_plans/models/active_wedding_plan.dart';

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

class MoreIdentitySummary {
  const MoreIdentitySummary({this.roleLabel, this.personaLabel});

  factory MoreIdentitySummary.from({
    ActiveWeddingPlan? activePlan,
    GuestOnboardingDraft? draft,
  }) {
    if (activePlan != null) {
      final roleLabel = activePlan.onboardingPath?.toUpperCase() == 'PROVIDER'
          ? 'مسار: مزود خدمة'
          : 'مسار: أرتب زفافي';
      final persona = personaCopyForBackend(activePlan.persona);
      return MoreIdentitySummary(
        roleLabel: roleLabel,
        personaLabel: persona.isKnown ? persona.identityLabel : null,
      );
    }

    if (draft != null) {
      final persona = personaCopyForGuest(draft.persona);
      return MoreIdentitySummary(
        roleLabel: appRoleLabel(draft.selectedPath),
        personaLabel: persona.isKnown ? persona.identityLabel : null,
      );
    }

    return const MoreIdentitySummary();
  }

  final String? roleLabel;
  final String? personaLabel;
}

class MoreMenuSectionTitle extends StatelessWidget {
  const MoreMenuSectionTitle({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.gold,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.title,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MoreHeader extends StatelessWidget {
  const MoreHeader({
    required this.notificationCount,
    required this.onNotifications,
    super.key,
  });

  final int notificationCount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'المزيد',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.burgundyDeep,
              fontFamily: AppTheme.displayFontFamily,
            ),
          ),
        ),
        const SizedBox(width: 14),
        _RoundIconButton(
          icon: LucideIcons.bell,
          badge: notificationCount > 0 ? '$notificationCount' : null,
          onTap: onNotifications,
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, this.onTap, this.badge});

  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: AppTheme.burgundy, size: 20),
            if (badge != null)
              PositionedDirectional(
                top: 1,
                start: 0,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.burgundy,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.surface, width: 2),
                  ),
                  child: Text(
                    badge!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MoreAvatarSourceTile extends StatelessWidget {
  const MoreAvatarSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.ivory,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.burgundy),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(LucideIcons.chevronLeft, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

class MoreProfileCard extends StatelessWidget {
  const MoreProfileCard({
    required this.name,
    this.phone,
    this.avatarUrl,
    this.isUpdatingAvatar = false,
    this.roleLabel,
    this.personaLabel,
    this.onEditAvatar,
    super.key,
  });

  final String name;
  final String? phone;
  final String? avatarUrl;
  final bool isUpdatingAvatar;
  final String? roleLabel;
  final String? personaLabel;
  final VoidCallback? onEditAvatar;

  @override
  Widget build(BuildContext context) {
    final imageUrl = avatarUrl?.trim();
    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: AppTheme.surface,
      child: Column(
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.gold.withAlpha(95)),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.ivory,
                  backgroundImage: imageUrl == null || imageUrl.isEmpty
                      ? null
                      : NetworkImage(imageUrl),
                  child: imageUrl == null || imageUrl.isEmpty
                      ? const Icon(
                          LucideIcons.user,
                          color: AppTheme.gold,
                          size: 26,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.burgundyDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone == null || phone!.trim().isEmpty
                          ? 'حساب أعرست'
                          : phone!,
                      textDirection: phone == null
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              if (onEditAvatar != null)
                Tooltip(
                  message: 'تعديل صورة الحساب',
                  child: InkWell(
                    onTap: isUpdatingAvatar ? null : onEditAvatar,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        shape: BoxShape.circle,
                        boxShadow: AppTheme.softShadow(opacity: .08),
                      ),
                      child: isUpdatingAvatar
                          ? const Center(
                              child: AarastInlineSpinner(color: AppTheme.ivory),
                            )
                          : const Icon(
                              LucideIcons.pencil,
                              color: AppTheme.ivory,
                              size: 19,
                            ),
                    ),
                  ),
                ),
            ],
          ),
          if (_hasText(roleLabel) || _hasText(personaLabel)) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_hasText(roleLabel)) _IdentityChip(label: roleLabel!),
                  if (_hasText(personaLabel))
                    _IdentityChip(label: personaLabel!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.burgundySoft.withAlpha(110),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.burgundy,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class MoreMenuGroup extends StatelessWidget {
  const MoreMenuGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: EdgeInsets.zero,
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft.withAlpha(80)),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, color: AppTheme.burgundySoft.withAlpha(150)),
          ],
        ],
      ),
    );
  }
}

class MoreActionTile extends StatelessWidget {
  const MoreActionTile({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronLeft,
              color: AppTheme.muted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// إجراءات الحساب الحساسة في مجموعة واحدة هادئة — لا كرتان منفوخان.
class MoreDangerGroup extends StatelessWidget {
  const MoreDangerGroup({
    required this.onLogout,
    required this.onDeleteAccount,
    super.key,
  });

  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: EdgeInsets.zero,
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.dangerSoft),
      child: Column(
        children: [
          _DangerTile(
            title: 'تسجيل الخروج',
            icon: LucideIcons.logOut,
            onTap: onLogout,
          ),
          Divider(height: 1, color: AppTheme.dangerSoft.withAlpha(150)),
          _DangerTile(
            title: 'حذف الحساب نهائيًا',
            icon: LucideIcons.trash2,
            onTap: onDeleteAccount,
          ),
        ],
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.dangerSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: AppTheme.danger, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(
              LucideIcons.chevronLeft,
              color: AppTheme.danger,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class MoreOptionalLoginTile extends StatelessWidget {
  const MoreOptionalLoginTile({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: EdgeInsets.zero,
      color: AppTheme.ivory,
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(LucideIcons.logIn, color: AppTheme.gold),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'تسجيل الدخول',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(LucideIcons.chevronLeft, color: AppTheme.gold),
          ],
        ),
      ),
    );
  }
}

class MoreVersionFooter extends StatelessWidget {
  const MoreVersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'Aarast V2.0',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'صُنع بحب في اليمن',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class MoreSheetHandle extends StatelessWidget {
  const MoreSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
