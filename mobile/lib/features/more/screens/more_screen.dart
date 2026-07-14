import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../onboarding/data/guest_onboarding_storage.dart';
import '../../onboarding/models/guest_onboarding_draft.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../widgets/more_screen_components.dart';

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
    final name = user?.name ?? 'مستخدم أعرست';
    final phone = user?.phone;

    return AarastScreenFrame(
      maxWidth: 520,
      safeAreaBottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 124),
        children: AarastStagger.children(context, [
          MoreHeader(
            notificationCount: notifications?.unreadCount ?? 0,
            onNotifications: () => context.push(AppRouter.notifications),
          ),
          const SizedBox(height: 14),
          FutureBuilder<GuestOnboardingDraft?>(
            future: _identityDraftFuture,
            builder: (context, snapshot) {
              final identity = MoreIdentitySummary.from(
                activePlan: activePlan,
                draft: snapshot.data,
              );
              return MoreProfileCard(
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
          const SizedBox(height: 18),
          const MoreMenuSectionTitle(title: 'خطط الزفاف'),
          const SizedBox(height: 6),
          MoreMenuGroup(
            children: [
              MoreActionTile(
                title: 'الخطط المشتركة معي',
                icon: LucideIcons.users,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.sharedWeddingPlans),
              ),
              MoreActionTile(
                title: 'خططي',
                icon: LucideIcons.calendarDays,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.weddingPlans),
              ),
              MoreActionTile(
                title: 'إنشاء خطة زفاف',
                icon: LucideIcons.plusCircle,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.createWeddingPlan),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const MoreMenuSectionTitle(title: 'الموردون'),
          const SizedBox(height: 6),
          // «تصفح الموردين» ليس هنا عمدًا — له تبويب خاص في الشريط السفلي.
          MoreMenuGroup(
            children: [
              MoreActionTile(
                title: 'الموردون المحفوظون',
                icon: LucideIcons.heart,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.favoriteProviders),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const MoreMenuSectionTitle(title: 'الحساب والمساعدة'),
          const SizedBox(height: 6),
          MoreMenuGroup(
            children: [
              MoreActionTile(
                title: 'الإعدادات',
                icon: LucideIcons.settings,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.settings),
              ),
              MoreActionTile(
                title: 'الدعم والمساعدة',
                icon: LucideIcons.headphones,
                iconColor: AppTheme.burgundy,
                iconBackground: AppTheme.burgundySoft,
                onTap: () => context.push(AppRouter.support),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasAccount)
            MoreOptionalLoginTile(onTap: () => context.push(AppRouter.login))
          else
            MoreDangerGroup(
              onLogout: () => _logout(context),
              onDeleteAccount: () => _deleteAccount(context),
            ),
          // كرت المزامنة في ذيل القائمة، ويختفي مع عنوانه عندما لا تتوفر
          // خدمة المزامنة أصلًا — لا عنوان معلقًا فوق كرت فارغ.
          if (_hasSyncService(context)) ...[
            const SizedBox(height: 14),
            const MoreMenuSectionTitle(title: 'المزامنة'),
            const SizedBox(height: 6),
            const MoreMenuGroup(children: [OfflineSyncNowTile()]),
          ],
          const SizedBox(height: 22),
          const MoreVersionFooter(),
        ]),
      ),
    );
  }

  static Future<void> _logout(BuildContext context) async {
    final confirmed = await showAarastBottomSheet<bool>(
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
                  const MoreSheetHandle(),
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
                    'هل ترغب في الخروج من حسابك الآن؟',
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

  static Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MoreSheetHandle(),
                  const SizedBox(height: 20),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppTheme.dangerSoft,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Icon(
                      LucideIcons.trash2,
                      color: AppTheme.danger,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حذف الحساب نهائياً',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيُحذف حسابك وكل بياناتك — خطط العرس والميزانيات والتكاليف والدفعات '
                    'والمهام وقوائم الضيوف — نهائياً ولا يمكن التراجع.',
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
                          label: 'حذف نهائي',
                          icon: LucideIcons.trash2,
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

    if (confirmed != true || !context.mounted) return;

    final auth = context.read<AuthController>();
    final deleted = await auth.deleteAccount();
    if (!context.mounted) return;
    if (deleted) {
      context.go(AppRouter.login);
    } else {
      AarastToast.showError(
        context,
        auth.errorMessage ?? 'تعذر حذف الحساب. حاول مرة أخرى.',
      );
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
      _showNotice(context, 'حجم الصورة يجب ألا يتجاوز 5MB.', isError: true);
      return;
    }

    final contentType = _avatarContentType(file);
    if (contentType == null) {
      _showNotice(
        context,
        'اختر صورة بصيغة JPG أو PNG أو WebP.',
        isError: true,
      );
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
      isError: !ok,
    );
  }

  static Future<ImageSource?> _showAvatarSourceSheet(BuildContext context) {
    return showAarastBottomSheet<ImageSource>(
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
                  const MoreSheetHandle(),
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
                  MoreAvatarSourceTile(
                    icon: LucideIcons.camera,
                    title: 'التقاط بالكاميرا',
                    onTap: () =>
                        Navigator.of(sheetContext).pop(ImageSource.camera),
                  ),
                  const SizedBox(height: 8),
                  MoreAvatarSourceTile(
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

  static void _showNotice(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    if (isError) {
      AarastToast.showError(context, message);
    } else {
      AarastToast.showSuccess(context, message);
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

bool _hasSyncService(BuildContext context) {
  try {
    context.watch<OfflineSyncService>();
    return true;
  } on ProviderNotFoundException {
    return false;
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
