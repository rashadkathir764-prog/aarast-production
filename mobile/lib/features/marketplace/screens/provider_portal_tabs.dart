import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/media/media_upload_api.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../chat/providers/chat_provider.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/provider_account_actions.dart';
import '../widgets/quote_status_chip.dart';

class ProviderHomeTab extends StatelessWidget {
  const ProviderHomeTab({required this.onOpenTab, super.key});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final profile = dashboard.profile;
    return RefreshIndicator(
      color: AppTheme.burgundy,
      onRefresh: dashboard.loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 128),
        children: [
          if (dashboard.isLoading && profile == null)
            const AarastScreenLoading(label: 'جارٍ تجهيز لوحة المزوّد...')
          else if (profile == null)
            AarastEmptyState(
              icon: LucideIcons.store,
              title: 'أكمل طلب الانضمام كمزوّد',
              message: 'بعد الاعتماد ستدير ملفك وخدماتك وطلبات العملاء من هنا.',
              action: FilledButton.icon(
                onPressed: () => context.push(AppRouter.providerApply),
                icon: const Icon(LucideIcons.badgeCheck),
                label: const Text('طلب الانضمام'),
              ),
            )
          else ...[
            _ProviderIdentityHero(profile: profile),
            const SizedBox(height: 16),
            _ProviderMetrics(
              summary: dashboard.summary,
              packageCount: dashboard.packages.length,
            ),
            const SizedBox(height: 18),
            _QuickActions(onOpenTab: onOpenTab),
            const SizedBox(height: 18),
            AarastSectionHeader(
              title: 'أحدث الطلبات',
              subtitle: 'طلبات عرض السعر الأحدث لنشاطك.',
              icon: LucideIcons.mailQuestion,
              actionLabel: dashboard.quoteRequests.isEmpty ? null : 'عرض الكل',
              onAction: dashboard.quoteRequests.isEmpty
                  ? null
                  : () => onOpenTab(1),
            ),
            const SizedBox(height: 12),
            if (dashboard.quoteRequests.isEmpty)
              const AarastEmptyState(
                icon: LucideIcons.inbox,
                title: 'لا توجد طلبات جديدة',
                message: 'حسّن ملفك وأضف صور خدماتك لزيادة فرص الظهور.',
              )
            else
              for (final quote in dashboard.quoteRequests.take(3)) ...[
                _QuoteSummaryTile(quote: quote),
                const SizedBox(height: 10),
              ],
          ],
          if (dashboard.errorMessage != null) ...[
            const SizedBox(height: 12),
            AarastErrorState(
              title: 'تعذر تحديث لوحة المزوّد',
              message: dashboard.errorMessage!,
              onRetry: dashboard.loadDashboard,
            ),
          ],
        ],
      ),
    );
  }
}

class ProviderRequestsTab extends StatefulWidget {
  const ProviderRequestsTab({super.key});

  @override
  State<ProviderRequestsTab> createState() => _ProviderRequestsTabState();
}

class _ProviderRequestsTabState extends State<ProviderRequestsTab> {
  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final quotes = dashboard.quoteRequests.where(_matches).toList();
    return RefreshIndicator(
      color: AppTheme.burgundy,
      onRefresh: dashboard.loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 128),
        children: [
          const AarastSectionHeader(
            title: 'طلبات الأسعار',
            subtitle: 'راجع الطلب، أرسل عرضك، ثم ناقش التفاصيل داخل أعرست.',
            icon: LucideIcons.mailQuestion,
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 4),
              ),
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: 'ALL',
                label: Text('الكل', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: 'NEW',
                label: Text('جديد', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: 'OFFERED',
                label: Text('تم العرض', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: 'CLOSED',
                label: Text('مغلق', maxLines: 1, softWrap: false),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (value) =>
                setState(() => _filter = value.first),
          ),
          const SizedBox(height: 16),
          if (dashboard.isLoading && dashboard.quoteRequests.isEmpty)
            const AarastScreenLoading(label: 'جارٍ تحميل الطلبات...')
          else if (quotes.isEmpty)
            const AarastEmptyState(
              icon: LucideIcons.inbox,
              title: 'لا توجد طلبات في هذا القسم',
              message: 'ستظهر الطلبات الجديدة هنا فور وصولها.',
            )
          else
            for (final quote in quotes) ...[
              _ProviderRequestCard(
                quote: quote,
                onChat: () =>
                    context.push(AppRouter.quoteConversation(quote.id)),
                onOffer: quote.lifecycleStatus == 'PENDING_PROVIDER'
                    ? () => _showOfferDialog(context, quote)
                    : null,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  bool _matches(QuoteRequest quote) {
    if (_filter == 'ALL') return true;
    if (_filter == 'NEW') {
      return quote.lifecycleStatus == 'PENDING_PROVIDER';
    }
    if (_filter == 'OFFERED') {
      return quote.lifecycleStatus == 'RECEIVED';
    }
    return const {
      'ACCEPTED',
      'REJECTED',
      'CANCELLED',
    }.contains(quote.lifecycleStatus);
  }
}

class ProviderServicesTab extends StatefulWidget {
  const ProviderServicesTab({super.key});

  @override
  State<ProviderServicesTab> createState() => _ProviderServicesTabState();
}

class _ProviderServicesTabState extends State<ProviderServicesTab> {
  bool _showServices = true;
  String? _busyServiceId;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    return RefreshIndicator(
      color: AppTheme.burgundy,
      onRefresh: dashboard.loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 128),
        children: [
          AarastSectionHeader(
            title: 'الخدمات والباقات',
            subtitle: 'كتالوج واضح وصور حقيقية تساعد العميل على الاختيار.',
            icon: LucideIcons.sparkles,
            actionLabel: 'إضافة',
            onAction: () => context.push(
              _showServices
                  ? AppRouter.providerServiceNew
                  : AppRouter.providerPackageNew,
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(LucideIcons.sparkles),
                label: Text('الخدمات'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(LucideIcons.gem),
                label: Text('الباقات'),
              ),
            ],
            selected: {_showServices},
            onSelectionChanged: (value) {
              setState(() => _showServices = value.first);
            },
          ),
          const SizedBox(height: 16),
          if (_showServices)
            if (dashboard.services.isEmpty)
              const AarastEmptyState(
                icon: LucideIcons.sparkles,
                title: 'لا توجد خدمات بعد',
                message: 'أضف أول خدمة ثم ارفع صورًا حقيقية من أعمالك.',
              )
            else
              for (final service in dashboard.services) ...[
                _ServiceManagementCard(
                  service: service,
                  busy: _busyServiceId == service.id,
                  onAddImage: () => _addImage(service),
                  onDeleteImage: (image) => _deleteImage(service, image),
                ),
                const SizedBox(height: 12),
              ]
          else if (dashboard.packages.isEmpty)
            const AarastEmptyState(
              icon: LucideIcons.gem,
              title: 'لا توجد باقات بعد',
              message: 'اجمع تفاصيل واضحة وسعرًا مناسبًا داخل باقة واحدة.',
            )
          else
            for (final item in dashboard.packages) ...[
              _PackageManagementCard(item: item),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Future<void> _addImage(MarketplaceService service) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 84,
      maxWidth: 2000,
    );
    if (file == null || !mounted) return;
    setState(() => _busyServiceId = service.id);
    try {
      final ticket = await context.read<MediaUploadApi>().uploadImage(
        file: file,
        purpose: 'service-image',
      );
      if (!mounted) return;
      await context.read<ProviderDashboardProvider>().addServiceImage(
        serviceId: service.id,
        imageUrl: ticket.publicUrl,
        altText: service.title,
      );
    } finally {
      if (mounted) setState(() => _busyServiceId = null);
    }
  }

  Future<void> _deleteImage(
    MarketplaceService service,
    ProviderServiceImage image,
  ) async {
    setState(() => _busyServiceId = service.id);
    await context.read<ProviderDashboardProvider>().deleteServiceImage(
      serviceId: service.id,
      imageId: image.id,
    );
    if (mounted) setState(() => _busyServiceId = null);
  }
}

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
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 22,
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

class _ProviderIdentityHero extends StatelessWidget {
  const _ProviderIdentityHero({required this.profile});

  final ProviderDashboardProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        color: AppTheme.burgundy,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        image: profile.coverUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(profile.coverUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  AppTheme.burgundy.withValues(alpha: 0.58),
                  BlendMode.srcOver,
                ),
              ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
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
              const Spacer(),
              AarastStatusPill(
                label: _providerStatus(profile.status),
                icon: LucideIcons.shieldCheck,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
              ),
            ],
          ),
          const Spacer(),
          Text(
            profile.businessName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            profile.city?.nameAr ?? 'ملف مزوّد أعرست',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderMetrics extends StatelessWidget {
  const _ProviderMetrics({required this.summary, required this.packageCount});

  final ProviderDashboardSummary summary;
  final int packageCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('${summary.activeServicesCount}', 'خدمة نشطة', LucideIcons.sparkles),
      ('$packageCount', 'باقة', LucideIcons.gem),
      (
        '${summary.newQuoteRequestsCount}',
        'طلب جديد',
        LucideIcons.mailQuestion,
      ),
      (summary.averageRating.toStringAsFixed(1), 'التقييم', LucideIcons.star),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.65,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return AarastCard(
          child: Row(
            children: [
              Icon(
                item.$3,
                color: index.isEven ? AppTheme.burgundy : AppTheme.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onOpenTab(1),
            icon: const Icon(LucideIcons.inbox),
            label: const Text('الطلبات'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => context.push(AppRouter.providerServiceNew),
            icon: const Icon(LucideIcons.plus),
            label: const Text('خدمة جديدة'),
          ),
        ),
      ],
    );
  }
}

class _QuoteSummaryTile extends StatelessWidget {
  const _QuoteSummaryTile({required this.quote});

  final QuoteRequest quote;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Row(
        children: [
          const Icon(LucideIcons.mailQuestion, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              quote.service?.title ?? 'طلب عرض سعر',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          QuoteStatusChip(status: quote.lifecycleStatus, compact: true),
        ],
      ),
    );
  }
}

class _ProviderRequestCard extends StatelessWidget {
  const _ProviderRequestCard({
    required this.quote,
    required this.onChat,
    this.onOffer,
  });

  final QuoteRequest quote;
  final VoidCallback onChat;
  final VoidCallback? onOffer;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quote.service?.title ?? 'طلب عرض سعر',
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              QuoteStatusChip(status: quote.lifecycleStatus, compact: true),
            ],
          ),
          if (quote.message?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              quote.message!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.muted, height: 1.45),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(LucideIcons.messageCircle),
                  label: const Text('محادثة'),
                ),
              ),
              if (onOffer != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOffer,
                    icon: const Icon(LucideIcons.send),
                    label: const Text('إرسال عرض'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceManagementCard extends StatelessWidget {
  const _ServiceManagementCard({
    required this.service,
    required this.busy,
    required this.onAddImage,
    required this.onDeleteImage,
  });

  final MarketplaceService service;
  final bool busy;
  final VoidCallback onAddImage;
  final ValueChanged<ProviderServiceImage> onDeleteImage;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  service.title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AarastStatusPill(
                label: service.isActive ? 'نشطة' : 'متوقفة',
                icon: service.isActive ? LucideIcons.check : LucideIcons.pause,
                color: service.isActive ? AppTheme.success : AppTheme.muted,
                backgroundColor: service.isActive
                    ? AppTheme.successSoft
                    : AppTheme.ivory,
              ),
            ],
          ),
          if (service.basePrice != null) ...[
            const SizedBox(height: 8),
            Text(
              '${service.basePrice} ${currencyLabelAr(service.currency)}',
              style: const TextStyle(
                color: AppTheme.burgundy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (service.images.isNotEmpty)
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: service.images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final image = service.images[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: Image.network(
                          image.imageUrl,
                          width: 112,
                          height: 92,
                          fit: BoxFit.cover,
                        ),
                      ),
                      PositionedDirectional(
                        top: 4,
                        start: 4,
                        child: IconButton.filledTonal(
                          tooltip: 'حذف الصورة',
                          visualDensity: VisualDensity.compact,
                          onPressed: busy ? null : () => onDeleteImage(image),
                          icon: const Icon(LucideIcons.trash2, size: 16),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : onAddImage,
            icon: busy
                ? const AarastInlineSpinner()
                : const Icon(LucideIcons.imagePlus),
            label: const Text('إضافة صورة للعمل'),
          ),
        ],
      ),
    );
  }
}

class _PackageManagementCard extends StatelessWidget {
  const _PackageManagementCard({required this.item});

  final ProviderPackage item;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Row(
        children: [
          const Icon(LucideIcons.gem, color: AppTheme.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (item.price != null)
                  Text(
                    '${item.price} ${currencyLabelAr(item.currency)}',
                    style: const TextStyle(
                      color: AppTheme.burgundy,
                      fontWeight: FontWeight.w800,
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

Future<void> _showOfferDialog(BuildContext context, QuoteRequest quote) async {
  final message = TextEditingController();
  final amount = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('إرسال عرض السعر'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: amount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'المبلغ (${currencyLabelAr(defaultCurrencyCode)})',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: message,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'تفاصيل العرض'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('إرسال'),
        ),
      ],
    ),
  );
  if (submitted == true && context.mounted) {
    await context.read<ProviderDashboardProvider>().createQuoteOffer(
      quoteRequestId: quote.id,
      message: message.text,
      amount: amount.text,
    );
  }
  message.dispose();
  amount.dispose();
}

String _providerStatus(String status) {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
      return 'معتمد';
    case 'NEEDS_CHANGES':
      return 'يحتاج تعديل';
    case 'SUSPENDED':
      return 'موقوف';
    case 'REJECTED':
      return 'غير معتمد';
    default:
      return 'قيد المراجعة';
  }
}
