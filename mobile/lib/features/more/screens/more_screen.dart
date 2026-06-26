import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/guest_onboarding_draft.dart';
import '../../onboarding/models/persona_copy.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../wedding_plans/models/active_wedding_plan.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  Future<GuestOnboardingDraft?>? _identityDraftFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _identityDraftFuture ??= _loadIdentityDraft();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (AppFeatureFlags.devBypassLoginGatesForUxExploration &&
          !await AuthActionGuard.hasAccount(context)) {
        return;
      }
      if (!mounted) return;
      _maybeReadNotifications(context)?.loadUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final notifications = _maybeWatchNotifications(context);
    final activePlan = _maybeWatchWeddingPlans(context)?.activePlan;
    final user = auth.user;
    final name = user?.name ?? 'مستخدم اعّرست';
    final phone = user?.phone;
    final isGuestExploration =
        AppFeatureFlags.devBypassLoginGatesForUxExploration &&
        auth.status != AuthStatus.authenticated;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 124),
                children: [
                  _MoreHeader(
                    name: name,
                    notificationCount: notifications?.unreadCount ?? 0,
                    onNotifications: () =>
                        context.push(AppRouter.notifications),
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<GuestOnboardingDraft?>(
                    future: _identityDraftFuture,
                    builder: (context, snapshot) {
                      final identity = _IdentitySummary.from(
                        activePlan: activePlan,
                        draft: snapshot.data,
                      );
                      return _ProfileCard(
                        name: name,
                        phone: phone,
                        roleLabel: identity.roleLabel,
                        personaLabel: identity.personaLabel,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _MenuGroup(
                    children: [
                      _MoreActionTile(
                        title: 'الخطط المشتركة معي',
                        subtitle: 'الخطط التي تمت مشاركتها معك للوصول إليها',
                        icon: Icons.groups_2_outlined,
                        iconColor: AppTheme.dMaroon,
                        iconBackground: AppTheme.dPinkBg,
                        onTap: () => context.push(AppRouter.sharedWeddingPlans),
                      ),
                      _MoreActionTile(
                        title: 'خططي',
                        subtitle: 'إدارة كل خطط الزفاف الخاصة بك',
                        icon: Icons.event_note_outlined,
                        iconColor: AppTheme.dMaroon,
                        iconBackground: AppTheme.dPinkBg,
                        onTap: () => context.push(AppRouter.weddingPlans),
                      ),
                      _MoreActionTile(
                        title: 'إنشاء خطة زفاف',
                        subtitle: 'ابدأ خطة جديدة لتنظيم يومك المميز',
                        icon: Icons.add_circle_outline_rounded,
                        iconColor: AppTheme.dMaroon,
                        iconBackground: AppTheme.dPinkBg,
                        onTap: () => context.push(AppRouter.createWeddingPlan),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MenuGroup(
                    children: [
                      _MoreActionTile(
                        title: 'الإعدادات',
                        subtitle: 'تخصيص التطبيق والتفضيلات',
                        icon: Icons.settings_outlined,
                        iconColor: AppTheme.dMaroon,
                        iconBackground: AppTheme.dPinkBg,
                        onTap: () => context.push(AppRouter.settings),
                      ),
                      _MoreActionTile(
                        title: 'الدعم والمساعدة',
                        subtitle: 'تواصل معنا أو استعرض الأسئلة الشائعة',
                        icon: Icons.support_agent_outlined,
                        iconColor: AppTheme.dMaroon,
                        iconBackground: AppTheme.dPinkBg,
                        onTap: () => context.push(AppRouter.support),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _MenuGroup(children: [OfflineSyncNowTile()]),
                  const SizedBox(height: 16),
                  if (isGuestExploration)
                    _OptionalLoginTile(
                      onTap: () => context.push(AppRouter.login),
                    )
                  else
                    _LogoutTile(onTap: () => _logout(context)),
                  const SizedBox(height: 22),
                  const _VersionFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _logout(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withAlpha(22),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: AppTheme.danger,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'تسجيل الخروج',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.dInk,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'هل ترغبين في الخروج من حسابك الآن؟',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(
                          color: AppTheme.dInkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                          ),
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('خروج'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthController>().logout();
      if (context.mounted) context.go(AppRouter.login);
    }
  }

  Future<GuestOnboardingDraft?> _loadIdentityDraft() async {
    try {
      return await context.read<GuestOnboardingStorage>().loadDraft();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

NotificationsProvider? _maybeReadNotifications(BuildContext context) {
  try {
    return context.read<NotificationsProvider>();
  } on ProviderNotFoundException {
    return null;
  }
}

NotificationsProvider? _maybeWatchNotifications(BuildContext context) {
  try {
    return context.watch<NotificationsProvider>();
  } on ProviderNotFoundException {
    return null;
  }
}

WeddingPlansProvider? _maybeWatchWeddingPlans(BuildContext context) {
  try {
    return context.watch<WeddingPlansProvider>();
  } on ProviderNotFoundException {
    return null;
  }
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

class _IdentitySummary {
  const _IdentitySummary({this.roleLabel, this.personaLabel});

  factory _IdentitySummary.from({
    ActiveWeddingPlan? activePlan,
    GuestOnboardingDraft? draft,
  }) {
    if (activePlan != null) {
      final roleLabel = activePlan.onboardingPath?.toUpperCase() == 'PROVIDER'
          ? 'مسار: مزود خدمة'
          : 'مسار: أرتب زفافي';
      final persona = personaCopyForBackend(activePlan.persona);
      return _IdentitySummary(
        roleLabel: roleLabel,
        personaLabel: persona.isKnown ? persona.identityLabel : null,
      );
    }

    if (draft != null) {
      final persona = personaCopyForGuest(draft.persona);
      return _IdentitySummary(
        roleLabel: appRoleLabel(draft.selectedPath),
        personaLabel: persona.isKnown ? persona.identityLabel : null,
      );
    }

    return const _IdentitySummary();
  }

  final String? roleLabel;
  final String? personaLabel;
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader({
    required this.name,
    required this.notificationCount,
    required this.onNotifications,
  });

  final String name;
  final int notificationCount;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'المزيد',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppTheme.dMaroonDeep,
                  fontWeight: FontWeight.w900,
                  fontFamily: AppTheme.displayFontFamily,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'كل ما تحتاجينه في مكان واحد',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.dInkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _RoundIconButton(
          icon: Icons.person_outline_rounded,
          onTap: () => _showAccountSnack(context, name),
        ),
        const SizedBox(width: 10),
        _RoundIconButton(
          icon: Icons.notifications_none_rounded,
          badge: notificationCount > 0 ? '$notificationCount' : null,
          onTap: onNotifications,
        ),
      ],
    );
  }

  void _showAccountSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.dCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.dLine),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: AppTheme.dMaroon),
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
                    color: AppTheme.dMaroon,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.dCard, width: 2),
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    this.phone,
    this.roleLabel,
    this.personaLabel,
  });

  final String name;
  final String? phone;
  final String? roleLabel;
  final String? personaLabel;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(20),
      color: AppTheme.dCard,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.dCreamBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.dGold.withAlpha(90)),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.dGoldDeep,
                  size: 38,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.dMaroonDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      phone == null || phone!.trim().isEmpty
                          ? 'حساب اعّرست'
                          : phone!,
                      textDirection: phone == null
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.dInkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.dGoldDeep,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.softShadow(opacity: .08),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 19,
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
        color: AppTheme.dPinkBg.withAlpha(110),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.dMaroon,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: EdgeInsets.zero,
      color: AppTheme.dCard2,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, color: AppTheme.dLine),
          ],
        ],
      ),
    );
  }
}

class _MoreActionTile extends StatelessWidget {
  const _MoreActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.dMuted,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: EdgeInsets.zero,
      color: AppTheme.dCard2,
      border: Border.all(color: AppTheme.danger.withAlpha(45)),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.danger.withAlpha(18),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppTheme.danger,
                size: 24,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                'تسجيل الخروج',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              color: AppTheme.danger,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionalLoginTile extends StatelessWidget {
  const _OptionalLoginTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: EdgeInsets.zero,
      color: AppTheme.dCreamBg,
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.login_rounded, color: AppTheme.dGoldDeep),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'تسجيل الدخول لاحقًا (اختياري)',
                style: TextStyle(
                  color: AppTheme.dInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: AppTheme.dGoldDeep),
          ],
        ),
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'Aarast V2.0',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.dMuted,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'صُنع بحب في اليمن',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.dMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.dLine,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
