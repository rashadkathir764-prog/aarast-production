import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthController;
import '../../chat/chat_api.dart' show ChatProvider;
import '../../marketplace/marketplace_api.dart'
    show MarketplaceService, ProviderDashboardProfile, ProviderReview;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_account_actions.dart';
import '../widgets/provider_bookings.dart' show ProviderSetupChecklist;
import '../widgets/provider_public_profile_action.dart';
import '../widgets/provider_stats_panel.dart' show ProviderStatsPanel;

class ProviderProfileTab extends StatefulWidget {
  const ProviderProfileTab({super.key});

  @override
  State<ProviderProfileTab> createState() => _ProviderProfileTabState();
}

class _ProviderProfileTabState extends State<ProviderProfileTab> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final profile = dashboard.profile;
    final canManage = dashboard.canManageProviderProfile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 128),
      children: [
        const AarastSectionHeader(
          title: 'ملفي التجاري',
          subtitle: 'هذه هي الهوية التي يراها العملاء في سوق المزوّدين.',
          icon: LucideIcons.userCircle,
        ),
        const SizedBox(height: 16),
        if (profile == null)
          const AarastEmptyState(
            icon: LucideIcons.store,
            title: 'لا يوجد ملف مزوّد',
            message: 'أكمل طلب الانضمام أولًا.',
          )
        else ...[
          _ProfileMediaCard(
            profile: profile,
            busy: _busy,
            onLogo: canManage ? () => _upload('provider-logo') : null,
            onCover: canManage ? () => _upload('provider-cover') : null,
          ),
          const SizedBox(height: 14),
          AarastCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  profile.businessName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  profile.description?.trim().isNotEmpty == true
                      ? profile.description!.trim()
                      : 'أضف نبذة توضح ما يميز نشاطك وخدماتك.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                if (canManage) ...[
                  FilledButton.icon(
                    onPressed: () =>
                        context.push(AppRouter.providerProfileEdit),
                    icon: const Icon(LucideIcons.pencil),
                    label: const Text('تعديل البيانات'),
                  ),
                  const SizedBox(height: 8),
                ],
                ProviderPublicProfileAction(
                  status: profile.status,
                  onPreview: () =>
                      context.push(AppRouter.providerDetails(profile.id)),
                ),
              ],
            ),
          ),
          // The services left the bottom bar for the calendar (p28, D39);
          // p35 lists them here, as «خدماتك».
          if (dashboard.canUseProviderOperations) ...[
            const SizedBox(height: 14),
            JourneyList(
              children: [
                JourneyListRow(
                  key: const Key('provider-profile-services'),
                  icon: LucideIcons.package,
                  color: AarastV3Color.primary,
                  soft: AarastV3Color.primarySoft,
                  title: 'خدماتك وباقاتك',
                  subtitle: _servicesLine(dashboard),
                  onTap: () => context.push(AppRouter.providerServices),
                ),
              ],
            ),
          ],
          // Moved from the home tab, which is now p13; the performance
          // page (p39) and the first-steps home (p14) replace them later.
          if (dashboard.canUseProviderOperations) ...[
            if (ProviderSetupChecklist.isIncomplete(dashboard)) ...[
              const SizedBox(height: 14),
              ProviderSetupChecklist(dashboard: dashboard),
            ],
            const SizedBox(height: 14),
            ProviderStatsPanel(dashboard: dashboard),
          ],
          const SizedBox(height: 14),
          _PortfolioGallery(services: dashboard.services),
          if (dashboard.canUseProviderOperations) ...[
            const SizedBox(height: 18),
            _ProviderReviewsSection(all: dashboard.reviews),
          ],
        ],
        const SizedBox(height: 22),
        ProviderAccountActions(
          onOpenSettings: () => context.push(AppRouter.settings),
          onSync: _syncProviderData,
          onExitWorkspace: _exitWorkspace,
          onLogout: _logout,
          onDeleteAccount: _deleteAccount,
        ),
      ],
    );
  }

  /// «3 خدمات · باقتين», or what to add first.
  static String _servicesLine(ProviderDashboardProvider dashboard) {
    final services = dashboard.services.length;
    final packages = dashboard.packages.length;
    if (services == 0 && packages == 0) return 'أضف خدماتك وأسعارك';
    return [
      if (services > 0)
        arabicCount(
          services,
          one: 'خدمة',
          two: 'خدمتين',
          few: 'خدمات',
          many: 'خدمة',
        ),
      if (packages > 0)
        arabicCount(
          packages,
          one: 'باقة',
          two: 'باقتين',
          few: 'باقات',
          many: 'باقة',
        ),
    ].join(' · ');
  }

  Future<void> _syncProviderData() async {
    final accountContexts = context.read<AccountContextController>();
    await accountContexts.refresh();
    if (!mounted) return;
    final dashboard = context.read<ProviderDashboardProvider>();
    final chat = context.read<ChatProvider>();
    await dashboard.loadDashboard();
    if (!mounted) return;
    if (dashboard.canUseProviderOperations) {
      await chat.loadConversations();
    }
    if (dashboard.errorMessage != null ||
        (dashboard.canUseProviderOperations && chat.errorMessage != null)) {
      throw StateError('Provider refresh failed');
    }
  }

  Future<void> _exitWorkspace() async {
    final router = GoRouter.of(context);
    final accountContexts = context.read<AccountContextController>();
    await accountContexts.exitWorkspace();
    await accountContexts.refresh();
    router.go(AppRouter.home);
  }

  Future<void> _logout() async {
    await context.read<AuthController>().logout();
  }

  Future<String?> _deleteAccount() async {
    final auth = context.read<AuthController>();
    final deleted = await auth.deleteAccount();
    if (!mounted) return deleted ? null : 'تعذر حذف الحساب.';
    if (deleted) return null;
    return auth.errorMessage ?? 'تعذر حذف الحساب. حاول مرة أخرى.';
  }

  Future<void> _upload(String purpose) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 84,
      maxWidth: purpose == 'provider-cover' ? 2200 : 1200,
    );
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final ticket = await context.read<MediaUploadApi>().uploadImage(
        file: file,
        purpose: purpose,
      );
      if (!mounted) return;
      final dashboard = context.read<ProviderDashboardProvider>();
      final saved = await dashboard.updateProfileMedia(
        logoUrl: purpose == 'provider-logo' ? ticket.publicUrl : null,
        coverUrl: purpose == 'provider-cover' ? ticket.publicUrl : null,
      );
      if (!mounted) return;
      if (!saved) {
        AarastToast.showError(
          context,
          dashboard.errorMessage ?? 'تعذر حفظ الصورة في ملف المزوّد.',
        );
        return;
      }
      AarastToast.showSuccess(
        context,
        purpose == 'provider-logo'
            ? 'تم تحديث شعار ملفك التجاري.'
            : 'تم تحديث غلاف ملفك التجاري.',
      );
    } on ApiException catch (error) {
      if (mounted) AarastToast.showError(context, error.message);
    } catch (_) {
      if (mounted) {
        AarastToast.showError(context, 'تعذر رفع الصورة الآن. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ProviderReviewsSection extends StatelessWidget {
  const _ProviderReviewsSection({required this.all});

  /// Every review the server sends the provider, whatever its status; only
  /// the published ones show on the public profile, so only those are listed.
  final List<ProviderReview> all;

  @override
  Widget build(BuildContext context) {
    final reviews = [
      for (final review in all)
        if (review.isPublished) review,
    ];
    final unpublished = all.length - reviews.length;
    final published = reviews.isEmpty
        ? 'لا توجد مراجعات منشورة حتى الآن.'
        : '${reviews.length} مراجعة منشورة على ملفك.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'مراجعات العملاء',
          subtitle: unpublished == 0
              ? published
              : '$published و$unpublished ما تظهر للعملاء (مخفية أو تحت المراجعة).',
          icon: LucideIcons.star,
        ),
        const SizedBox(height: 10),
        if (reviews.isEmpty)
          const AarastEmptyState(
            icon: LucideIcons.messageSquare,
            title: 'لا توجد مراجعات بعد',
            message: 'ستظهر هنا المراجعات المنشورة من العملاء.',
          )
        else
          for (final review in reviews) ...[
            AarastCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.userName?.trim().isNotEmpty == true
                              ? review.userName!.trim()
                              : 'عميل اعّرست',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      AarastStatusPill(
                        label: '${review.rating}/5',
                        icon: LucideIcons.star,
                        color: AppTheme.focus,
                        backgroundColor: AppTheme.brandMuted,
                      ),
                    ],
                  ),
                  if (review.comment?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      review.comment!.trim(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _ProfileMediaCard extends StatelessWidget {
  const _ProfileMediaCard({
    required this.profile,
    required this.busy,
    required this.onLogo,
    required this.onCover,
  });

  final ProviderDashboardProfile profile;
  final bool busy;

  /// Null while the server keeps the profile read-only; the button is gone.
  final VoidCallback? onLogo;
  final VoidCallback? onCover;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg),
                ),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: AppTheme.brandMuted,
                  child: profile.coverUrl == null
                      ? const Icon(
                          LucideIcons.image,
                          color: AppTheme.brand,
                          size: 36,
                        )
                      : Image.network(profile.coverUrl!, fit: BoxFit.cover),
                ),
              ),
              if (onCover != null)
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: IconButton.filledTonal(
                    tooltip: 'تغيير الغلاف',
                    onPressed: busy ? null : onCover,
                    icon: const Icon(LucideIcons.camera),
                  ),
                ),
              PositionedDirectional(
                start: 18,
                bottom: -34,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 39,
                      backgroundColor: AppTheme.surfaceRaised,
                      backgroundImage: profile.logoUrl == null
                          ? null
                          : NetworkImage(profile.logoUrl!),
                      child: profile.logoUrl == null
                          ? const Icon(
                              LucideIcons.store,
                              color: AppTheme.focus,
                              size: 30,
                            )
                          : null,
                    ),
                    if (onLogo != null)
                      PositionedDirectional(
                        end: -8,
                        bottom: -4,
                        child: IconButton.filled(
                          tooltip: 'تغيير الشعار',
                          visualDensity: VisualDensity.compact,
                          onPressed: busy ? null : onLogo,
                          icon: const Icon(LucideIcons.camera, size: 16),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 44),
        ],
      ),
    );
  }
}

class _PortfolioGallery extends StatelessWidget {
  const _PortfolioGallery({required this.services});

  final List<MarketplaceService> services;

  @override
  Widget build(BuildContext context) {
    final images = services.expand((service) => service.images).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AarastSectionHeader(
          title: 'معرض الأعمال',
          subtitle: 'مجمّع تلقائيًا من صور خدماتك.',
          icon: LucideIcons.galleryThumbnails,
        ),
        const SizedBox(height: 12),
        if (images.isEmpty)
          const AarastEmptyState(
            icon: LucideIcons.galleryThumbnails,
            title: 'المعرض فارغ',
            message: 'أضف صورًا داخل الخدمات لتظهر هنا وفي ملفك العام.',
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.15,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Image.network(images[index].imageUrl, fit: BoxFit.cover),
            ),
          ),
      ],
    );
  }
}
