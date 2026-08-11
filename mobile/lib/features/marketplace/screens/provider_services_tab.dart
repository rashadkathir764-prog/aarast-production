import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import 'provider_catalog_management_widgets.dart';

typedef ProviderServiceImagePicker = Future<List<XFile>> Function();
typedef ProviderServiceImageUploader =
    Future<MediaUploadTicket> Function(XFile file);

class ProviderServicesTab extends StatefulWidget {
  const ProviderServicesTab({super.key, this.pickImages, this.uploadImage});

  final ProviderServiceImagePicker? pickImages;
  final ProviderServiceImageUploader? uploadImage;

  @override
  State<ProviderServicesTab> createState() => _ProviderServicesTabState();
}

class _ProviderServicesTabState extends State<ProviderServicesTab> {
  static const _maximumImagesPerSelection = 10;

  bool _showServices = true;
  String? _busyServiceId;
  String? _busyPackageId;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    return RefreshIndicator(
      color: AppTheme.brand,
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
            style: const ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(AppTheme.surfaceRaised),
            ),
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
                  onEdit: () => _editService(service),
                  onToggleActive: () => _toggleService(service),
                  onAddImages: () => _addImages(service),
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
              ProviderPackageManagementCard(
                item: item,
                priceLabel: item.price == null
                    ? null
                    : '${item.price} ${currencyLabelAr(item.currency)}',
                busy: _busyPackageId == item.id,
                onEdit: () => _editPackage(item),
                onToggleActive: () => _togglePackage(item),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Future<void> _editService(MarketplaceService service) async {
    setState(() => _busyServiceId = service.id);
    try {
      final saved = await showProviderServiceEditDialog(context, service);
      if (!mounted || saved != true) return;
      AarastToast.showSuccess(context, 'تم تحديث الخدمة.');
    } finally {
      if (mounted) setState(() => _busyServiceId = null);
    }
  }

  Future<void> _toggleService(MarketplaceService service) async {
    final confirmed = service.isActive
        ? await confirmProviderListingPause(context, kind: 'الخدمة')
        : true;
    if (confirmed != true || !mounted) return;
    setState(() => _busyServiceId = service.id);
    try {
      final dashboard = context.read<ProviderDashboardProvider>();
      final saved = await dashboard.setServiceActive(
        serviceId: service.id,
        isActive: !service.isActive,
      );
      if (!mounted) return;
      if (saved) {
        AarastToast.showSuccess(
          context,
          service.isActive ? 'تم إيقاف الخدمة.' : 'تم تفعيل الخدمة.',
        );
      } else {
        AarastToast.showError(
          context,
          dashboard.errorMessage ?? 'تعذر تحديث حالة الخدمة.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyServiceId = null);
    }
  }

  Future<void> _editPackage(ProviderPackage item) async {
    setState(() => _busyPackageId = item.id);
    try {
      final saved = await showProviderPackageEditDialog(context, item);
      if (!mounted || saved != true) return;
      AarastToast.showSuccess(context, 'تم تحديث الباقة.');
    } finally {
      if (mounted) setState(() => _busyPackageId = null);
    }
  }

  Future<void> _togglePackage(ProviderPackage item) async {
    final confirmed = item.isActive
        ? await confirmProviderListingPause(context, kind: 'الباقة')
        : true;
    if (confirmed != true || !mounted) return;
    setState(() => _busyPackageId = item.id);
    try {
      final dashboard = context.read<ProviderDashboardProvider>();
      final saved = await dashboard.setPackageActive(
        packageId: item.id,
        isActive: !item.isActive,
      );
      if (!mounted) return;
      if (saved) {
        AarastToast.showSuccess(
          context,
          item.isActive ? 'تم إيقاف الباقة.' : 'تم تفعيل الباقة.',
        );
      } else {
        AarastToast.showError(
          context,
          dashboard.errorMessage ?? 'تعذر تحديث حالة الباقة.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyPackageId = null);
    }
  }

  Future<void> _addImages(MarketplaceService service) async {
    late final List<XFile> files;
    try {
      files =
          await (widget.pickImages?.call() ??
              ImagePicker().pickMultiImage(
                imageQuality: 84,
                maxWidth: 2000,
                limit: _maximumImagesPerSelection,
              ));
    } catch (_) {
      if (mounted) {
        AarastToast.showError(
          context,
          'تعذر فتح معرض الصور. تحقق من الإذن وحاول مرة أخرى.',
        );
      }
      return;
    }
    if (files.isEmpty || !mounted) return;

    setState(() => _busyServiceId = service.id);
    var savedCount = 0;
    String? lastError;
    try {
      final dashboard = context.read<ProviderDashboardProvider>();
      final uploader =
          widget.uploadImage ??
          (XFile file) => context.read<MediaUploadApi>().uploadImage(
            file: file,
            purpose: 'service-image',
          );

      for (final file in files.take(_maximumImagesPerSelection)) {
        if (!mounted) return;
        try {
          final ticket = await uploader(file);
          if (!mounted) return;
          final saved = await dashboard.addServiceImage(
            serviceId: service.id,
            imageUrl: ticket.publicUrl,
            altText: service.title,
          );
          if (saved) {
            savedCount++;
          } else {
            lastError =
                dashboard.errorMessage ?? 'تعذر إضافة إحدى الصور إلى الخدمة.';
          }
        } on ApiException catch (error) {
          lastError = error.message;
          if (error.statusCode != null && error.statusCode! >= 500) break;
        } catch (_) {
          lastError = 'تعذر رفع إحدى الصور.';
        }
      }

      if (!mounted) return;
      final selectedCount = files.take(_maximumImagesPerSelection).length;
      if (savedCount == selectedCount) {
        AarastToast.showSuccess(
          context,
          savedCount == 1
              ? 'تمت إضافة الصورة إلى الخدمة.'
              : 'تمت إضافة $savedCount صور إلى الخدمة.',
        );
      } else if (savedCount > 0) {
        AarastToast.showInfo(
          context,
          'تمت إضافة $savedCount من $selectedCount صور. '
          '${lastError ?? 'حاول إضافة الصور المتبقية مرة أخرى.'}',
        );
      } else {
        AarastToast.showError(
          context,
          lastError ?? 'تعذر رفع الصور الآن. حاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyServiceId = null);
    }
  }

  Future<void> _deleteImage(
    MarketplaceService service,
    ProviderServiceImage image,
  ) async {
    setState(() => _busyServiceId = service.id);
    try {
      final dashboard = context.read<ProviderDashboardProvider>();
      final deleted = await dashboard.deleteServiceImage(
        serviceId: service.id,
        imageId: image.id,
      );
      if (!mounted) return;
      if (deleted) {
        AarastToast.showSuccess(context, 'تم حذف الصورة من الخدمة.');
      } else {
        AarastToast.showError(
          context,
          dashboard.errorMessage ?? 'تعذر حذف الصورة من الخدمة.',
        );
      }
    } finally {
      if (mounted) setState(() => _busyServiceId = null);
    }
  }
}

class _ServiceManagementCard extends StatelessWidget {
  const _ServiceManagementCard({
    required this.service,
    required this.busy,
    required this.onEdit,
    required this.onToggleActive,
    required this.onAddImages,
    required this.onDeleteImage,
  });

  final MarketplaceService service;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onAddImages;
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
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              AarastStatusPill(
                label: service.isActive ? 'نشطة' : 'متوقفة',
                icon: service.isActive ? LucideIcons.check : LucideIcons.pause,
                color: service.isActive
                    ? AppTheme.success
                    : AppTheme.textSecondary,
                backgroundColor: service.isActive
                    ? AppTheme.successSoft
                    : AppTheme.canvas,
              ),
            ],
          ),
          if (service.basePrice != null) ...[
            const SizedBox(height: 8),
            Text(
              '${service.basePrice} ${currencyLabelAr(service.currency)}',
              style: const TextStyle(
                color: AppTheme.brand,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('provider-service-edit-${service.id}'),
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(LucideIcons.pencil),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: Key('provider-service-toggle-${service.id}'),
                  onPressed: busy ? null : onToggleActive,
                  icon: Icon(
                    service.isActive ? LucideIcons.pause : LucideIcons.play,
                  ),
                  label: Text(service.isActive ? 'إيقاف' : 'تفعيل'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            service.images.isEmpty
                ? 'لا توجد صور لهذه الخدمة بعد.'
                : 'صور الخدمة (${service.images.length})',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
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
            onPressed: busy ? null : onAddImages,
            icon: busy
                ? const AarastInlineSpinner()
                : const Icon(LucideIcons.imagePlus),
            label: Text(busy ? 'جاري رفع الصور...' : 'إضافة صور للأعمال'),
          ),
        ],
      ),
    );
  }
}
