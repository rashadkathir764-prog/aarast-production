import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/aarast_motion.dart';
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
  static const _avatarMaxBytes = 5 * 1024 * 1024;

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
    final hasAccount = auth.status == AuthStatus.authenticated && user != null;
    final name = user?.name ?? 'مستخدم اعّرست';
    final phone = user?.phone;

    return AarastScreenFrame(
      maxWidth: 520,
      safeAreaBottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 124),
        children: AarastStagger.children(context, [
          _MoreHeader(
            name: name,
            avatarUrl: user?.avatarUrl,
            notificationCount: notifications?.unreadCount ?? 0,
            onNotifications: () => context.push(AppRouter.notifications),
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
                avatarUrl: user?.avatarUrl,
                isUpdatingAvatar: auth.isSubmitting,
                roleLabel: identity.roleLabel,
                personaLabel: identity.personaLabel,
                onEditAvatar: hasAccount ? () => _changeAvatar(context) : null,
              );
            },
          ),
          const SizedBox(height: 20),
          const _MenuSectionTitle(
            title: 'خطط الزفاف',
            subtitle: 'إدارة خططك أو فتح ما تمت مشاركته معك',
          ),
          const SizedBox(height: 8),
          _MenuGroup(
            children: [
              _MoreActionTile(
                title: 'الخطط المشتركة معي',
                subtitle: 'الخطط التي تمت مشاركتها معك للوصول إليها',
                icon: LucideIcons.users,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.sharedWeddingPlans),
              ),
              _MoreActionTile(
                title: 'خططي',
                subtitle: 'إدارة كل خطط الزفاف الخاصة بك',
                icon: LucideIcons.calendarDays,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.weddingPlans),
              ),
              _MoreActionTile(
                title: 'إنشاء خطة زفاف',
                subtitle: 'ابدأ خطة جديدة لتنظيم يومك المميز',
                icon: LucideIcons.plusCircle,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.createWeddingPlan),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _MenuSectionTitle(
            title: 'الموردون',
            subtitle: 'الموردون المحفوظون وطلبات المقارنة',
          ),
          const SizedBox(height: 8),
          _MenuGroup(
            children: [
              _MoreActionTile(
                title: 'الموردون المحفوظون',
                subtitle: 'افتح الصالات والمصورين والخدمات التي حفظتها',
                icon: LucideIcons.heart,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.favoriteProviders),
              ),
              _MoreActionTile(
                title: 'تصفح الموردين',
                subtitle: 'ابحث عن موردين واطلب عروض أسعار بدون حجز أو دفع',
                icon: LucideIcons.store,
                iconColor: AppTheme.gold,
                iconBackground: AppTheme.goldSoft,
                onTap: () => context.push(AppRouter.providerMarketplace),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _MenuSectionTitle(
            title: 'الحساب والمساعدة',
            subtitle: 'إعدادات هادئة، دعم، وتنبيهات عند الحاجة',
          ),
          const SizedBox(height: 8),
          _MenuGroup(
            children: [
              _MoreActionTile(
                title: 'الإعدادات',
                subtitle: 'تخصيص التطبيق والتفضيلات',
                icon: LucideIcons.settings,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.settings),
              ),
              _MoreActionTile(
                title: 'الدعم والمساعدة',
                subtitle: 'تواصل معنا أو استعرض الأسئلة الشائعة',
                icon: LucideIcons.headphones,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.support),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _MenuSectionTitle(
            title: 'المزامنة',
            subtitle: 'حالة البيانات المحلية والحسابية',
          ),
          const SizedBox(height: 8),
          const _MenuGroup(children: [OfflineSyncNowTile()]),
          const SizedBox(height: 16),
          if (!hasAccount)
            _OptionalLoginTile(onTap: () => context.push(AppRouter.login))
          else
            _LogoutTile(onTap: () => _logout(context)),
          const SizedBox(height: 22),
          const _VersionFooter(),
        ]),
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
                      color: AppTheme.dangerSoft,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Icon(
                      LucideIcons.logOut,
                      color: AppTheme.danger,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'تسجيل الخروج',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'هل ترغبين في الخروج من حسابك الآن؟',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: AarastButton(
                          label: 'إلغاء',
                          variant: AarastButtonVariant.secondary,
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AarastButton(
                          label: 'خروج',
                          icon: LucideIcons.logOut,
                          variant: AarastButtonVariant.danger,
                          onPressed: () => Navigator.of(sheetContext).pop(true),
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

  Future<void> _changeAvatar(BuildContext context) async {
    if (!await AuthActionGuard.requireAccount(
      context,
      reason: 'سجّل الدخول لتحديث صورة حسابك ومزامنتها بأمان.',
    )) {
      return;
    }
    if (!context.mounted) return;

    final source = await _showAvatarSourceSheet(context);
    if (source == null || !context.mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 86,
      maxWidth: 1600,
    );
    if (file == null || !context.mounted) return;

    final size = await file.length();
    if (!context.mounted) return;
    if (size > _avatarMaxBytes) {
      _showNotice(context, 'حجم الصورة يجب ألا يتجاوز 5MB.');
      return;
    }

    final contentType = _avatarContentType(file);
    if (contentType == null) {
      _showNotice(context, 'اختر صورة بصيغة JPG أو PNG أو WebP.');
      return;
    }

    final bytes = await file.readAsBytes();
    if (!context.mounted) return;

    final auth = context.read<AuthController>();
    final ok = await auth.updateAvatar(
      bytes: bytes,
      fileName: _avatarFileName(file),
      contentType: contentType,
    );
    if (!context.mounted) return;

    _showNotice(
      context,
      ok ? 'تم تحديث صورة الحساب.' : auth.errorMessage ?? 'تعذر تحديث الصورة.',
    );
  }

  static Future<ImageSource?> _showAvatarSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  const SizedBox(height: 18),
                  Text(
                    'تحديث صورة الحساب',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 14),
                  _AvatarSourceTile(
                    icon: LucideIcons.camera,
                    title: 'التقاط بالكاميرا',
                    onTap: () =>
                        Navigator.of(sheetContext).pop(ImageSource.camera),
                  ),
                  const SizedBox(height: 8),
                  _AvatarSourceTile(
                    icon: LucideIcons.image,
                    title: 'اختيار من المعرض',
                    onTap: () =>
                        Navigator.of(sheetContext).pop(ImageSource.gallery),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String? _avatarContentType(XFile file) {
    final mimeType = file.mimeType?.trim().toLowerCase();
    if (mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp') {
      return mimeType;
    }
    final name = _avatarFileName(file).toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return null;
  }

  static String _avatarFileName(XFile file) {
    final name = file.name.trim();
    if (name.isNotEmpty) return name;
    final pathParts = file.path.split(RegExp(r'[\\/]'));
    final fromPath = pathParts.isEmpty ? '' : pathParts.last.trim();
    return fromPath.isEmpty ? 'avatar.jpg' : fromPath;
  }

  static void _showNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

class _MenuSectionTitle extends StatelessWidget {
  const _MenuSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.gold,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.title,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader({
    required this.name,
    required this.notificationCount,
    required this.onNotifications,
    this.avatarUrl,
  });

  final String name;
  final String? avatarUrl;
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
                  color: AppTheme.burgundyDeep,
                  fontWeight: FontWeight.w900,
                  fontFamily: AppTheme.displayFontFamily,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'كل أدواتك في مكان واحد',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        _RoundIconButton(
          icon: LucideIcons.user,
          avatarUrl: avatarUrl,
          onTap: () => _showAccountSnack(context, name),
        ),
        const SizedBox(width: 10),
        _RoundIconButton(
          icon: LucideIcons.bell,
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
  const _RoundIconButton({
    required this.icon,
    this.onTap,
    this.badge,
    this.avatarUrl,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? badge;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final imageUrl = avatarUrl?.trim();
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (imageUrl == null || imageUrl.isEmpty)
              Icon(icon, color: AppTheme.burgundy)
            else
              ClipOval(
                child: Image.network(
                  imageUrl,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Icon(icon, color: AppTheme.burgundy),
                ),
              ),
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

class _AvatarSourceTile extends StatelessWidget {
  const _AvatarSourceTile({
    required this.icon,
    required this.title,
    required this.onTap,
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    this.phone,
    this.avatarUrl,
    this.isUpdatingAvatar = false,
    this.roleLabel,
    this.personaLabel,
    this.onEditAvatar,
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
      padding: const EdgeInsets.all(20),
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
                  radius: 38,
                  backgroundColor: AppTheme.ivory,
                  backgroundImage: imageUrl == null || imageUrl.isEmpty
                      ? null
                      : NetworkImage(imageUrl),
                  child: imageUrl == null || imageUrl.isEmpty
                      ? const Icon(
                          LucideIcons.user,
                          color: AppTheme.gold,
                          size: 38,
                        )
                      : null,
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
                        color: AppTheme.burgundyDeep,
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
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
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

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.children});

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
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronLeft,
              color: AppTheme.muted,
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
      color: AppTheme.surface,
      border: Border.all(color: AppTheme.dangerSoft),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.dangerSoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Icon(
                LucideIcons.logOut,
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
              LucideIcons.chevronLeft,
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

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

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
