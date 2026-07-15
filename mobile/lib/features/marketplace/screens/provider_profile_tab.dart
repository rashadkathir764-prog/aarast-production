import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/media/media_upload_api.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../chat/providers/chat_provider.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/provider_account_actions.dart';

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
            onLogo: () => _upload(profile, 'provider-logo'),
            onCover: () => _upload(profile, 'provider-cover'),
          ),
          const SizedBox(height: 14),
          AarastCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  profile.businessName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  profile.description?.trim().isNotEmpty == true
                      ? profile.description!.trim()
                      : 'أضف نبذة توضح ما يميز نشاطك وخدماتك.',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => context.push(AppRouter.providerProfileEdit),
                  icon: const Icon(LucideIcons.pencil),
                  label: const Text('تعديل البيانات'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push(AppRouter.providerDetails(profile.id)),
                  icon: const Icon(LucideIcons.eye),
                  label: const Text('معاينة الملف العام'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _PortfolioGallery(services: dashboard.services),
        ],
        const SizedBox(height: 22),
        ProviderAccountActions(
          onOpenSettings: () => context.push(AppRouter.settings),
          onSync: _syncProviderData,
          onLogout: _logout,
        ),
      ],
    );
  }

  Future<void> _syncProviderData() async {
    final dashboard = context.read<ProviderDashboardProvider>();
    final chat = context.read<ChatProvider>();
    await Future.wait([dashboard.loadDashboard(), chat.loadConversations()]);
    if (dashboard.errorMessage != null || chat.errorMessage != null) {
      throw StateError('Provider refresh failed');
    }
  }

  Future<void> _logout() async {
    await context.read<AuthController>().logout();
    if (mounted) context.go(AppRouter.login);
  }

  Future<void> _upload(ProviderDashboardProfile profile, String purpose) async {
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
      final cityId = profile.cityId;
      final phone = profile.phone;
      if (cityId == null || phone == null) return;
      await context.read<ProviderDashboardProvider>().updateProfile(
        businessName: profile.businessName,
        phone: phone,
        cityId: cityId,
        description: profile.description,
        logoUrl: purpose == 'provider-logo' ? ticket.publicUrl : null,
        coverUrl: purpose == 'provider-cover' ? ticket.publicUrl : null,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
  final VoidCallback onLogo;
  final VoidCallback onCover;

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
                  color: AppTheme.burgundySoft,
                  child: profile.coverUrl == null
                      ? const Icon(
                          LucideIcons.image,
                          color: AppTheme.burgundy,
                          size: 36,
                        )
                      : Image.network(profile.coverUrl!, fit: BoxFit.cover),
                ),
              ),
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
                      backgroundColor: AppTheme.surface,
                      backgroundImage: profile.logoUrl == null
                          ? null
                          : NetworkImage(profile.logoUrl!),
                      child: profile.logoUrl == null
                          ? const Icon(
                              LucideIcons.store,
                              color: AppTheme.gold,
                              size: 30,
                            )
                          : null,
                    ),
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
