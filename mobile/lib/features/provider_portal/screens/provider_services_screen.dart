import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceService, ProviderPackage, latestPriceUpdate;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_listing_sheet.dart';
import '../widgets/provider_profile_parts.dart';
import '../widgets/provider_request_parts.dart' show providerGroupedAmount;

/// p36 «خدماتك»: his services and packages as customers price them, each
/// opening its edit. What a package includes is his own words (its
/// description, B-07); the season price and the teams are not kept by the
/// server (F18, D-2), so they are not drawn. Opened from «ملفي» (D39).
class ProviderServicesScreen extends StatelessWidget {
  const ProviderServicesScreen({this.now, super.key});

  /// The clock for «آخر تحديث قبل أسبوعين»; tests pin it.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final services = dashboard.services;
    final packages = dashboard.packages;
    final category = dashboard.profile?.primaryCategory?.nameAr.trim() ?? '';
    final subtitle = [
      if (category.isNotEmpty) category,
      if (services.isNotEmpty)
        arabicCount(
          services.length,
          one: 'خدمة',
          two: 'خدمتين',
          few: 'خدمات',
          many: 'خدمة',
        ),
      if (packages.isNotEmpty)
        arabicCount(
          packages.length,
          one: 'باقة',
          two: 'باقتين',
          few: 'باقات',
          many: 'باقة',
        ),
    ].join(' · ');
    final updated = latestPriceUpdate(services);
    final footer = [
      ?providerPricesCurrencyLine(services, packages),
      if (updated != null) 'آخر تحديث ${providerAgoLabel(updated, now: now)}',
    ].join(' · ');
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
              title: 'خدماتك',
              subtitle: subtitle.isEmpty ? null : subtitle,
            ),
            JourneySectionTitle(
              'الخدمات',
              action: 'أضف خدمة',
              onAction: () => context.push(AppRouter.providerServiceNew),
            ),
            if (services.isEmpty)
              const _Empty(
                key: Key('provider-services-empty'),
                text: 'ما عندك خدمة لسا. ملفك ما يظهر في الدليل قبل أول خدمة.',
              )
            else
              for (final service in services)
                _ListingCard(
                  key: Key('provider-service-${service.id}'),
                  title: service.title,
                  price: service.basePrice,
                  includes: service.description,
                  note: service.priceUnit,
                  active: service.isActive,
                  onTap: () => _edit(context, service: service),
                ),
            JourneySectionTitle(
              'الباقات',
              action: 'أضف باقة',
              onAction: () => context.push(AppRouter.providerPackageNew),
            ),
            if (packages.isEmpty)
              const _Empty(
                key: Key('provider-packages-empty'),
                text: 'الباقة تجمع خدماتك بسعر واحد، وتطلع لك في العرض السريع.',
              )
            else
              for (final package in packages)
                _ListingCard(
                  key: Key('provider-package-${package.id}'),
                  title: package.title,
                  price: package.price,
                  includes: package.description,
                  active: package.isActive,
                  onTap: () => _edit(context, package: package),
                ),
            if (footer.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  footer,
                  key: const Key('provider-services-footer'),
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context, {
    MarketplaceService? service,
    ProviderPackage? package,
  }) async {
    final saved = await showProviderListingSheet(
      context,
      service: service,
      package: package,
    );
    if (saved == true && context.mounted) {
      AarastToast.showSuccess(
        context,
        service != null ? 'انحفظت الخدمة.' : 'انحفظت الباقة.',
      );
    }
  }
}

/// One service or package (prototype `pkg`): name and price, then what it
/// includes; a paused one says so.
class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.title,
    required this.price,
    required this.includes,
    required this.active,
    required this.onTap,
    this.note,
    super.key,
  });

  final String title;
  final String? price;
  final String? includes;
  final String? note;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = providerGroupedAmount(price);
    final what = includes?.trim() ?? '';
    final unit = note?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AarastPressable(
        onTap: onTap,
        semanticLabel: [title, ?amount, if (!active) 'موقوفة'].join('، '),
        borderRadius: BorderRadius.circular(22),
        child: JourneyBox(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                        color: active
                            ? AarastV3Color.ink
                            : AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                  if (amount != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      amount,
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                        color: active
                            ? AarastV3Color.ink
                            : AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              if (what.isNotEmpty)
                Text(
                  'يشمل: $what',
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                    height: 1.5,
                  ),
                ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              if (!active) ...[
                const SizedBox(height: 6),
                const JourneyTag(
                  label: 'موقوفة، ما يشوفها العرسان',
                  color: AarastV3Color.textMuted,
                  soft: AarastV3Color.line,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const JourneyIconTile(
            icon: LucideIcons.package,
            color: AarastV3Color.primary,
            soft: AarastV3Color.primarySoft,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
