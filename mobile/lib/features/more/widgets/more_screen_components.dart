import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_header_actions.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/models/account_context.dart';
import '../../onboarding/models/guest_onboarding_draft.dart';
import '../../onboarding/models/persona_copy.dart';

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

class MoreIdentitySummary {
  const MoreIdentitySummary({this.roleLabel, this.personaLabel});

  factory MoreIdentitySummary.from({
    AccountContext? selectedContext,
    GuestOnboardingDraft? draft,
  }) {
    if (selectedContext != null) {
      return MoreIdentitySummary(
        roleLabel: switch (selectedContext.role) {
          AccountContextRole.owner => 'مسار: صاحب الخطة',
          AccountContextRole.contributor => 'مسار: مساهم',
          AccountContextRole.provider => 'مسار: مزود خدمة',
        },
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
      padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x1),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AarastV3Type.label(
          context,
        ).copyWith(color: AarastV3Color.primary),
      ),
    );
  }
}

class MoreHeader extends StatelessWidget {
  const MoreHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return AarastV3ContextBar(
      section: 'مساحتك',
      contextLabel: 'الحساب والخطط والمساعدة',
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
          color: AppTheme.canvas,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(LucideIcons.chevronLeft, color: AppTheme.textSecondary),
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
      color: AppTheme.surfaceRaised,
      child: Column(
        children: [
          Row(
            children: [
              AarastAccountAvatar(
                userName: name,
                avatarUrl: imageUrl,
                size: 56,
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
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (phone?.trim().isNotEmpty == true)
                      AarastPhoneText(
                        phone: phone!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppTheme.textSecondary),
                      )
                    else
                      Text(
                        'حساب أعرست',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppTheme.textSecondary),
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
                        color: AppTheme.focus,
                        shape: BoxShape.circle,
                      ),
                      child: isUpdatingAvatar
                          ? const Center(
                              child: AarastInlineSpinner(
                                color: AppTheme.canvas,
                              ),
                            )
                          : const Icon(
                              LucideIcons.pencil,
                              color: AppTheme.canvas,
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
        color: AppTheme.brandMuted.withAlpha(110),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.brand,
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
    return AarastV3ContinuousSurface(children: children);
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
    return AarastV3ListRow(
      title: title,
      accent: iconColor,
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: iconBackground,
          borderRadius: BorderRadius.circular(AarastV3Radius.control),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
    );
  }
}

/// Keeps destructive account operations out of the main information flow.
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
    return AarastV3ContinuousSurface(
      children: [
        AarastV3ListRow(
          title: 'إدارة الحساب',
          subtitle: 'تسجيل الخروج أو حذف الحساب',
          accent: AarastV3Color.textMuted,
          leading: const Icon(
            LucideIcons.shield,
            color: AarastV3Color.textMuted,
            size: 19,
          ),
          onTap: () => _openAccountActions(context),
        ),
      ],
    );
  }

  Future<void> _openAccountActions(BuildContext context) async {
    await showAarastBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('إدارة الحساب', style: AarastV3Type.section(sheetContext)),
            const SizedBox(height: AarastV3Space.x2),
            Text(
              'الإجراءات الحساسة منفصلة حتى لا تُنفذ بالخطأ.',
              style: AarastV3Type.body(sheetContext),
            ),
            const SizedBox(height: AarastV3Space.x4),
            AarastV3ContinuousSurface(
              children: [
                _DangerTile(
                  title: 'تسجيل الخروج',
                  icon: LucideIcons.logOut,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => onLogout(),
                    );
                  },
                ),
                _DangerTile(
                  title: 'حذف الحساب نهائيًا',
                  icon: LucideIcons.trash2,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => onDeleteAccount(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
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
    return AarastV3ContinuousSurface(
      children: [
        AarastV3ListRow(
          title: 'تسجيل الدخول',
          subtitle: 'احفظ خططك واستعدها من أي جهاز',
          accent: AarastV3Color.primary,
          leading: const Icon(
            LucideIcons.logIn,
            color: AarastV3Color.primary,
            size: 19,
          ),
          onTap: onTap,
        ),
      ],
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
            'أعرست',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'صُنع بحب في اليمن',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.textSecondary,
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
