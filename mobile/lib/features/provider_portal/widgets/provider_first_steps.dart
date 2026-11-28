import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../providers/provider_dashboard_provider.dart';

/// p14 «ما وصلك طلب لسا»: the home before his first request. It lists what
/// still makes his profile complete for customers, each with its place, and
/// how often his page was opened in the last 30 days. Nothing promises more
/// requests or a higher place (F17): the directory lists him once he has an
/// active service and orders by featured and age only. The verification and
/// share-link tips need B-17 and B-27, so they are not drawn.
class ProviderFirstSteps extends StatelessWidget {
  const ProviderFirstSteps({
    required this.dashboard,
    required this.onOpenProfile,
    super.key,
  });

  final ProviderDashboardProvider dashboard;

  /// «ملفي», where his logo is changed.
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final profile = dashboard.profile;
    final hasService = dashboard.services.any((service) => service.isActive);
    final photos = profile?.portfolioPhotos ?? 0;
    final steps = <Widget>[
      // The photos come first and always show here: the couples choose
      // from them, and a profile went live with none (the home hid the
      // step until a service existed).
      _Step(
        key: const Key('provider-first-photos'),
        icon: LucideIcons.image,
        title: 'صور من شغلك',
        subtitle: providerPhotosStepLine(photos),
        action: 'إضافة',
        onTap: () => context.push(AppRouter.providerGallery),
      ),
      if (!hasService)
        _Step(
          key: const Key('provider-first-service'),
          icon: LucideIcons.package,
          title: 'خدمة بسعرها',
          subtitle: 'ملفك ما يظهر في الدليل قبل أول خدمة',
          action: 'إضافة',
          onTap: () => context.push(AppRouter.providerServiceNew),
        ),
      if (profile?.logoUrl?.trim().isNotEmpty != true)
        _Step(
          key: const Key('provider-first-logo'),
          icon: LucideIcons.store,
          title: 'شعارك',
          subtitle: 'يطلع جنب اسمك للعرسان',
          action: 'إضافة',
          onTap: onOpenProfile,
        ),
      if (profile?.description?.trim().isNotEmpty != true)
        _Step(
          key: const Key('provider-first-about'),
          icon: LucideIcons.fileEdit,
          title: 'نبذة عن شغلك',
          subtitle: 'تظهر في ملفك للعرسان',
          action: 'كتابة',
          onTap: () => context.push(AppRouter.providerProfileEdit),
        ),
    ];
    final views = dashboard.summary.stats?.profileViews;
    return Column(
      key: const Key('provider-home-first'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AarastV3Space.x4),
        const Center(
          child: JourneyIconTile(
            icon: LucideIcons.sprout,
            color: AarastV3Color.primary,
            soft: AarastV3Color.primarySoft,
            size: AarastV3Size.markLarge,
            radius: 24,
          ),
        ),
        const SizedBox(height: AarastV3Space.x3),
        Text(
          'ما وصلك طلب لسا',
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.pageTitle,
            weight: JourneyType.bold,
          ),
        ),
        const SizedBox(height: AarastV3Space.x1),
        Text(
          steps.isEmpty
              ? 'أول ما يوصلك طلب عرض من عريس أو عروسة، يطلع هنا.'
              : 'هذا اللي يكمّل ملفك قدام العرسان:',
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
        ),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x4),
          JourneyList(children: steps),
        ],
        if (views != null) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyBox(
            key: const Key('provider-home-views'),
            padding: const EdgeInsets.all(AarastV3Space.x3),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.eye,
                  size: AarastV3Icon.md,
                  color: AarastV3Color.textMuted,
                ),
                const SizedBox(width: AarastV3Space.x2),
                Expanded(
                  child: Text(
                    views == 0
                        ? 'ما انفتح ملفك في آخر 30 يومًا'
                        : 'انفتح ملفك ${arabicCount(views, one: 'مرة وحدة', two: 'مرتين', few: 'مرات', many: 'مرة')} في آخر 30 يومًا',
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// How many photos make a profile the couples can choose from.
const providerPhotosWanted = 6;

/// «صور من شغلك»'s line, on the welcome (p10) and the first home (p14):
/// why the photos matter and how many, until he has that many.
String providerPhotosStepLine(int photos) {
  const why = 'العرسان يختارون من صورك';
  if (photos <= 0) return '$why. حط $providerPhotosWanted صور على الأقل.';
  final has = arabicCount(
    photos,
    one: 'صورة وحدة',
    two: 'صورتين',
    few: 'صور',
    many: 'صورة',
  );
  if (photos < providerPhotosWanted) {
    return 'عندك $has. $why، حط $providerPhotosWanted على الأقل.';
  }
  return 'عندك $has في ملفك.';
}

/// One step: its icon, what to do, why, and a soft button to its place.
class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return JourneyListRow(
      icon: icon,
      color: AarastV3Color.primary,
      soft: AarastV3Color.primarySoft,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      // RA-MO-361: the button drawn is heard, not only the row.
      trailingIsAction: true,
      trailing: JourneyButton(
        label: action,
        background: AarastV3Color.primarySoft,
        foreground: AarastV3Color.primary,
        onPressed: onTap,
      ),
    );
  }
}
