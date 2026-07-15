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
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';

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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.ink,
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
