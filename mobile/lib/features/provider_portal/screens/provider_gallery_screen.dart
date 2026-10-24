import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceService, ProviderServiceImage;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_profile_parts.dart';

typedef ProviderGalleryImagePicker = Future<List<XFile>> Function();
typedef ProviderGalleryImageUploader =
    Future<MediaUploadTicket> Function(XFile file);

/// p37 «معرض الشغل + التغطية»: his work's photos, one album per service (the
/// server keeps photos per service only, F14), and where he works, which is
/// his city and the shop's place (F18). Photos go live when added, so no
/// «نراجعها» tag and no review line; the women's album and the travel
/// cities are not kept by the server (B-15, B-16).
class ProviderGalleryScreen extends StatefulWidget {
  const ProviderGalleryScreen({this.pickImages, this.uploadImage, super.key});

  final ProviderGalleryImagePicker? pickImages;
  final ProviderGalleryImageUploader? uploadImage;

  @override
  State<ProviderGalleryScreen> createState() => _ProviderGalleryScreenState();
}

class _ProviderGalleryScreenState extends State<ProviderGalleryScreen> {
  static const _maximumImagesPerSelection = 10;

  String? _serviceId;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final services = dashboard.services;
    final profile = dashboard.profile;
    final selected = _selected(services);
    final photos = providerPhotoCount(services);
    final city = profile?.city?.nameAr.trim() ?? '';
    final address = profile?.address?.trim() ?? '';
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: AarastV3Color.primary,
        onRefresh: dashboard.loadDashboard,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            JourneySubHeader(
              title: 'معرض الشغل',
              subtitle: photos == 0
                  ? 'ما فيه صور لسا'
                  : arabicCount(
                      photos,
                      one: 'صورة وحدة',
                      two: 'صورتين',
                      few: 'صور',
                      many: 'صورة',
                    ),
            ),
            if (selected == null)
              JourneyListState(
                key: const Key('provider-gallery-empty'),
                phase: JourneyListPhase.empty,
                section: JourneySection.home,
                emptyIcon: LucideIcons.image,
                emptyTitle: 'الصور تنضاف لكل خدمة',
                emptyMessage: 'أضف خدمتك أول، وبعدها صور شغلها.',
                emptyAction: 'أضف خدمة',
                onEmptyAction: () => context.push(AppRouter.providerServiceNew),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final service in services)
                    JourneyChip(
                      key: Key('provider-gallery-album-${service.id}'),
                      label: service.title,
                      selected: service.id == selected.id,
                      onTap: () => setState(() => _serviceId = service.id),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (selected.images.isNotEmpty)
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final image in selected.images)
                      _Photo(
                        key: Key('provider-gallery-photo-${image.id}'),
                        image: image,
                        onTap: _busy ? null : () => _openPhoto(selected, image),
                      ),
                  ],
                ),
              if (selected.images.isNotEmpty) const SizedBox(height: 12),
              JourneyButton(
                key: const Key('provider-gallery-add'),
                label: _busy ? 'نرفع الصور…' : 'أضف صور في ${selected.title}',
                icon: LucideIcons.imagePlus,
                background: AarastV3Color.primarySoft,
                foreground: AarastV3Color.primary,
                expand: true,
                loading: _busy,
                onPressed: () => _addImages(selected),
              ),
              const SizedBox(height: 12),
              const JourneyNote(
                icon: LucideIcons.eye,
                text: 'الصور اللي تضيفها تظهر في ملفك للعرسان على طول.',
              ),
            ],
            if (city.isNotEmpty || address.isNotEmpty) ...[
              JourneySectionTitle(
                'التغطية',
                action: dashboard.canManageProviderProfile ? 'عدّل' : null,
                onAction: () => context.push(AppRouter.providerProfileEdit),
              ),
              JourneyBox(
                key: const Key('provider-gallery-coverage'),
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    if (city.isNotEmpty) _Fact(label: 'المدينة', value: city),
                    if (address.isNotEmpty)
                      _Fact(label: 'المحل', value: address),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  MarketplaceService? _selected(List<MarketplaceService> services) {
    if (services.isEmpty) return null;
    for (final service in services) {
      if (service.id == _serviceId) return service;
    }
    return services.first;
  }

  /// A photo opens large with «احذف الصورة».
  Future<void> _openPhoto(
    MarketplaceService service,
    ProviderServiceImage image,
  ) async {
    final remove = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: service.title,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                image.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: AarastV3Color.line),
              ),
            ),
          ),
          const SizedBox(height: 14),
          JourneyButton(
            key: const Key('provider-gallery-photo-delete'),
            label: 'احذف الصورة',
            icon: LucideIcons.trash2,
            background: AarastV3Color.dangerSoft,
            foreground: AarastV3Color.danger,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final dashboard = context.read<ProviderDashboardProvider>();
      final deleted = await dashboard.deleteServiceImage(
        serviceId: service.id,
        imageId: image.id,
      );
      if (!mounted) return;
      if (deleted) {
        AarastToast.showSuccess(context, 'انحذفت الصورة.');
      } else {
        AarastToast.showError(
          context,
          dashboard.errorMessage ?? 'ما قدرنا نحذف الصورة، جرب مرة ثانية.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
          'ما قدرنا نفتح الصور. تأكد من الإذن وجرب مرة ثانية.',
        );
      }
      return;
    }
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    var saved = 0;
    String? lastError;
    final chosen = files.take(_maximumImagesPerSelection).toList();
    try {
      final dashboard = context.read<ProviderDashboardProvider>();
      final upload =
          widget.uploadImage ??
          (XFile file) => context.read<MediaUploadApi>().uploadImage(
            file: file,
            purpose: 'service-image',
          );
      for (final file in chosen) {
        if (!mounted) return;
        try {
          final ticket = await upload(file);
          if (!mounted) return;
          final ok = await dashboard.addServiceImage(
            serviceId: service.id,
            imageUrl: ticket.publicUrl,
            altText: service.title,
          );
          if (ok) {
            saved++;
          } else {
            lastError = dashboard.errorMessage ?? 'ما انحفظت صورة منها.';
          }
        } on ApiException catch (error) {
          lastError = error.message;
          if (error.statusCode != null && error.statusCode! >= 500) break;
        } catch (_) {
          lastError = 'ما قدرنا نرفع صورة منها.';
        }
      }
      if (!mounted) return;
      if (saved == chosen.length) {
        AarastToast.showSuccess(
          context,
          saved == 1 ? 'انضافت الصورة.' : 'انضافت $saved صور.',
        );
      } else if (saved > 0) {
        AarastToast.showInfo(
          context,
          'انضافت $saved من ${chosen.length} صور. '
          '${lastError ?? 'جرب الباقي مرة ثانية.'}',
        );
      } else {
        AarastToast.showError(
          context,
          lastError ?? 'ما قدرنا نرفع الصور، جرب مرة ثانية.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.image, required this.onTap, super.key});

  final ProviderServiceImage image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onTap,
      semanticLabel: image.altText?.trim().isNotEmpty == true
          ? image.altText!.trim()
          : 'صورة',
      borderRadius: BorderRadius.circular(14),
      child: ColoredBox(
        color: AarastV3Color.line,
        child: Image.network(
          image.imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// «المدينة   صنعاء» (prototype `kv`).
class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: JourneyType.of(
                JourneyType.detail,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
            ),
          ),
        ],
      ),
    );
  }
}
