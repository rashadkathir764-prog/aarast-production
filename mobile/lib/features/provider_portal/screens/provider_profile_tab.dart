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
import '../../marketplace/marketplace_api.dart'
    show ProviderDashboardProfile, providerRespondsLabel;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_join_parts.dart';
import '../widgets/provider_profile_parts.dart';

/// p35 «ملفي»: who he is to customers, and a row for each piece of his
/// profile. Only what the server holds is shown (classification p35): the
/// «موثّق» tag and «التوثيق» row only with `verifiedAt`, the rating only
/// with ratings, the reply speed only when the public page has it (F16), the
/// coverage as his city; no «تيك توك مربوط», no teams and no unanswered
/// review dot (B-09, B-15, B-16, B-17).
class ProviderProfileTab extends StatefulWidget {
  const ProviderProfileTab({this.now, super.key});

  /// The clock for «موثّق من أسبوعين»; tests pin it.
  final DateTime? now;

  @override
  State<ProviderProfileTab> createState() => _ProviderProfileTabState();
}

class _ProviderProfileTabState extends State<ProviderProfileTab> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProviderDashboardProvider>().loadResponsiveness();
    });
  }

  Future<void> _refresh() async {
    final dashboard = context.read<ProviderDashboardProvider>();
    await dashboard.loadDashboard();
    await dashboard.loadResponsiveness();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final profile = dashboard.profile;
    return RefreshIndicator(
      color: AarastV3Color.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AarastV3Space.x4,
          AarastV3Space.x2,
          AarastV3Space.x4,
          AarastV3Density.pageBottom,
        ),
        children: [
          if (profile == null)
            dashboard.isLoading
                ? const JourneyListState(
                    phase: JourneyListPhase.loading,
                    section: JourneySection.home,
                  )
                : JourneyListState(
                    phase: JourneyListPhase.error,
                    section: JourneySection.home,
                    onRetry: dashboard.loadDashboard,
                  )
          else
            ..._profile(context, dashboard, profile),
        ],
      ),
    );
  }

  List<Widget> _profile(
    BuildContext context,
    ProviderDashboardProvider dashboard,
    ProviderDashboardProfile profile,
  ) {
    final operations = dashboard.canUseProviderOperations;
    final canManage = dashboard.canManageProviderProfile;
    final responds = operations
        ? providerRespondsLabel(dashboard.responsiveness)
        : null;
    final verifiedAt = profile.verifiedAt;
    final city = profile.city?.nameAr.trim() ?? '';
    final published = dashboard.reviews.where((r) => r.isPublished).length;
    final tags = [
      if (verifiedAt != null)
        const JourneyTag(
          key: Key('provider-me-verified'),
          label: 'موثّق',
          color: AarastV3Color.mint,
          soft: AarastV3Color.mintSoft,
        ),
      if (profile.ratingCount > 0)
        JourneyTag(
          label:
              '★ ${providerRatingLabel(profile.ratingAverage, profile.ratingCount)}',
          color: AarastV3Color.brandAccentStrong,
          soft: AarastV3Color.brandAccentSoft,
        ),
      if (responds != null)
        JourneyTag(
          key: const Key('provider-me-responds'),
          label: responds,
          color: AarastV3Color.cobalt,
          soft: AarastV3Color.cobaltSoft,
        ),
    ];
    return [
      const SizedBox(height: AarastV3Space.x1),
      ProviderIdentityRow(
        name: profile.businessName,
        kind: providerKindLine(
          category: profile.primaryCategory?.nameAr,
          city: profile.city?.nameAr,
        ),
        logoUrl: profile.logoUrl,
        trailing: canManage
            ? JourneyRoundButton(
                key: const Key('provider-me-edit'),
                icon: LucideIcons.pencil,
                tooltip: 'عدّل ملفك',
                onPressed: _busy ? null : () => _openEdit(context),
              )
            : null,
      ),
      if (tags.isNotEmpty) ...[
        const SizedBox(height: AarastV3Space.x2),
        Wrap(spacing: 6, runSpacing: 6, children: tags),
      ],
      // His public page exists only while he is approved.
      if (operations) ...[
        const SizedBox(height: AarastV3Space.x3),
        JourneyButton(
          key: const Key('provider-me-preview'),
          label: 'كيف يشوفك العرسان',
          icon: LucideIcons.eye,
          background: AarastV3Color.primarySoft,
          foreground: AarastV3Color.primary,
          expand: true,
          large: true,
          onPressed: () => context.push(AppRouter.providerDetails(profile.id)),
        ),
      ],
      const SizedBox(height: AarastV3Space.x3),
      JourneyList(
        children: [
          if (operations) ...[
            JourneyListRow(
              key: const Key('provider-profile-services'),
              icon: LucideIcons.package,
              color: AarastV3Color.primary,
              soft: AarastV3Color.primarySoft,
              title: 'خدماتك وباقاتك',
              subtitle: providerServicesLine(
                dashboard.services,
                dashboard.packages,
              ),
              onTap: () => context.push(AppRouter.providerServices),
            ),
            JourneyListRow(
              key: const Key('provider-me-gallery'),
              icon: LucideIcons.image,
              color: AarastV3Color.primary,
              soft: AarastV3Color.primarySoft,
              title: 'معرض الشغل',
              subtitle: providerGalleryLine(profile),
              onTap: () => context.push(AppRouter.providerGallery),
            ),
          ],
          if (city.isNotEmpty)
            JourneyListRow(
              key: const Key('provider-me-coverage'),
              icon: LucideIcons.mapPin,
              color: AarastV3Color.primary,
              soft: AarastV3Color.primarySoft,
              title: 'التغطية',
              subtitle: city,
              onTap: canManage
                  ? () => context.push(AppRouter.providerProfileEdit)
                  : null,
            ),
          if (verifiedAt != null)
            JourneyListRow(
              key: const Key('provider-me-verification'),
              icon: LucideIcons.badgeCheck,
              color: AarastV3Color.primary,
              soft: AarastV3Color.primarySoft,
              title: 'التوثيق',
              subtitle: 'موثّق ${_since(verifiedAt)}',
            ),
          if (operations) ...[
            JourneyListRow(
              key: const Key('provider-me-reviews'),
              icon: LucideIcons.star,
              color: AarastV3Color.primary,
              soft: AarastV3Color.primarySoft,
              title: 'التقييمات',
              subtitle: published == 0
                  ? 'ما فيه تقييم لسا'
                  : profile.ratingCount > 0
                  ? providerRatingLabel(
                      profile.ratingAverage,
                      profile.ratingCount,
                    )
                  : arabicCount(
                      published,
                      one: 'تقييم واحد',
                      two: 'تقييمين',
                      few: 'تقييمات',
                      many: 'تقييم',
                    ),
              onTap: () => showJourneySheet<void>(
                context: context,
                builder: (_) => ProviderReviewsSheet(all: dashboard.reviews),
              ),
            ),
            JourneyListRow(
              key: const Key('provider-me-performance'),
              icon: LucideIcons.barChart3,
              color: AarastV3Color.primary,
              soft: AarastV3Color.primarySoft,
              title: 'أداؤك',
              subtitle: 'آخر 30 يوم',
              onTap: () => context.push(AppRouter.providerPerformance),
            ),
            // B-18 (p47): the customers' agreed, paid and left, read only.
            JourneyListRow(
              key: const Key('provider-me-ledger'),
              icon: LucideIcons.wallet,
              color: AarastV3Color.primary,
              soft: AarastV3Color.primarySoft,
              title: 'حساباتك',
              subtitle: 'وصلك وباقي لك من حجوزاتك',
              onTap: () => context.push(AppRouter.providerLedger),
            ),
            // B-20: how many weddings he takes on one day; not drawn on
            // p35 (the drawn teams are gone for good, D41).
            JourneyListRow(
              key: const Key('provider-me-capacity'),
              icon: LucideIcons.calendarDays,
              color: AarastV3Color.primary,
              soft: AarastV3Color.primarySoft,
              title: 'كم عرس تاخذ في اليوم',
              subtitle: profile.dailyBookingCapacity == 1
                  ? 'عرس واحد'
                  : arabicCount(
                      profile.dailyBookingCapacity,
                      one: 'عرس واحد',
                      two: 'عرسين',
                      few: 'أعراس',
                      many: 'عرس',
                    ),
              onTap: () => showJourneySheet<void>(
                context: context,
                builder: (_) => ProviderCapacitySheet(
                  initial: profile.dailyBookingCapacity,
                  save: (value) async =>
                      await dashboard.updateDailyCapacity(value)
                      ? null
                      : dashboard.errorMessage ??
                            'ما قدرنا نحفظ العدد. جرّب مرة ثانية.',
                ),
              ),
            ),
            // B-43: the placement the team recorded, and until when; not
            // drawn on p35 (handoff design differences). Shown only while one
            // is recorded, and it leads nowhere: the app never invites paying
            // for it outside the store (D96, Play's payments policy).
            if (providerFeaturedLine(
                  startsAt: profile.featuredStartsAt,
                  endsAt: profile.featuredEndsAt,
                  now: widget.now,
                )
                case final featured?)
              JourneyListRow(
                key: const Key('provider-me-featured'),
                icon: LucideIcons.crown,
                color: AarastV3Color.primary,
                soft: AarastV3Color.primarySoft,
                title: 'الظهور المميز',
                subtitle: featured,
              ),
            JourneyListRow(
              key: const Key('provider-me-share'),
              icon: LucideIcons.share2,
              color: AarastV3Color.primary,
              soft: AarastV3Color.primarySoft,
              title: 'شارك ملفك',
              subtitle: 'بطاقة لحالة واتساب',
              onTap: () => context.push(AppRouter.providerShare),
            ),
          ],
          JourneyListRow(
            key: const Key('provider-me-settings'),
            icon: LucideIcons.settings,
            color: AarastV3Color.primary,
            soft: AarastV3Color.primarySoft,
            title: 'الإعدادات',
            subtitle: 'التنبيهات والحساب',
            onTap: () => context.push(AppRouter.providerSettings),
          ),
        ],
      ),
    ];
  }

  /// «من أسبوعين».
  String _since(DateTime at) {
    final ago = providerAgoLabel(at, now: widget.now);
    return switch (ago) {
      'اليوم' => 'اليوم',
      'أمس' => 'من أمس',
      _ => 'من ${ago.replaceFirst('قبل ', '')}',
    };
  }

  /// His details, logo and cover, from the pencil by his name.
  Future<void> _openEdit(BuildContext context) async {
    final choice = await showJourneySheet<String>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: 'عدّل ملفك',
        children: [
          JourneyList(
            children: [
              JourneyListRow(
                key: const Key('provider-me-edit-details'),
                icon: LucideIcons.fileEdit,
                color: AarastV3Color.primary,
                soft: AarastV3Color.primarySoft,
                title: 'بياناتك',
                subtitle: 'الاسم والمدينة والنبذة',
                onTap: () => Navigator.of(sheetContext).pop('details'),
              ),
              JourneyListRow(
                key: const Key('provider-me-edit-logo'),
                icon: LucideIcons.store,
                color: AarastV3Color.primary,
                soft: AarastV3Color.primarySoft,
                title: 'الشعار',
                subtitle: 'الصورة اللي جنب اسمك',
                onTap: () => Navigator.of(sheetContext).pop('provider-logo'),
              ),
              JourneyListRow(
                key: const Key('provider-me-edit-cover'),
                icon: LucideIcons.image,
                color: AarastV3Color.primary,
                soft: AarastV3Color.primarySoft,
                title: 'الغلاف',
                subtitle: 'الصورة العريضة فوق ملفك',
                onTap: () => Navigator.of(sheetContext).pop('provider-cover'),
              ),
            ],
          ),
        ],
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'details') {
      await context.push(AppRouter.providerProfileEdit);
      return;
    }
    await _upload(choice);
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
          dashboard.errorMessage ?? 'ما قدرنا نحفظ الصورة في ملفك.',
        );
        return;
      }
      AarastToast.showSuccess(
        context,
        purpose == 'provider-logo' ? 'تغيّر شعارك.' : 'تغيّر غلافك.',
      );
    } on ApiException catch (error) {
      if (mounted) AarastToast.showError(context, error.message);
    } catch (_) {
      if (mounted) {
        AarastToast.showError(context, 'ما قدرنا نرفع الصورة، جرب مرة ثانية.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
