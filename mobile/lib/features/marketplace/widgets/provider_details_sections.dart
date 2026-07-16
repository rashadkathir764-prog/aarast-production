import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/phone/phone_number_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/marketplace_models.dart';

class ProviderDetailsSections extends StatelessWidget {
  const ProviderDetailsSections({
    required this.provider,
    required this.services,
    required this.packages,
    required this.reviews,
    required this.onRequestQuote,
    super.key,
  });

  final MarketplaceProvider provider;
  final List<MarketplaceService> services;
  final List<ProviderPackage> packages;
  final List<ProviderReview> reviews;
  final ValueChanged<MarketplaceService> onRequestQuote;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _pad(_AboutCard(provider: provider)),
        const SizedBox(height: 16),
        _pad(
          _ServicesSection(services: services, onRequestQuote: onRequestQuote),
        ),
        const SizedBox(height: 16),
        _pad(_PackagesSection(packages: packages)),
        const SizedBox(height: 16),
        _pad(_ReviewsSection(reviews: reviews)),
      ],
    );
  }
}

Widget _pad(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

class _AboutCard extends StatefulWidget {
  const _AboutCard({required this.provider});

  final MarketplaceProvider provider;

  @override
  State<_AboutCard> createState() => _AboutCardState();
}

class _AboutCardState extends State<_AboutCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final description = widget.provider.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    final text = hasDescription
        ? description
        : 'لا توجد نبذة مفصلة بعد، لكن يمكنك طلب عرض سعر لمعرفة التفاصيل المناسبة لخطتك.';
    final canExpand = hasDescription && description.length > 150;

    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AarastSectionHeader(
            title: 'نبذة عن المورد',
            icon: LucideIcons.info,
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: AppTheme.motionFast,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Text(
              text,
              textAlign: TextAlign.right,
              maxLines: canExpand && !_expanded ? 3 : null,
              overflow: canExpand && !_expanded
                  ? TextOverflow.ellipsis
                  : TextOverflow.clip,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
          ),
          if (canExpand)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(_expanded ? 'عرض أقل' : 'عرض المزيد'),
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.provider.phone?.trim().isNotEmpty == true)
                AarastStatusPill(
                  label:
                      PhoneNumberUtils.directionalDisplay(
                        widget.provider.phone,
                      ) ??
                      widget.provider.phone!.trim(),
                  icon: LucideIcons.phone,
                  color: AppTheme.ink,
                  backgroundColor: AppTheme.ivory,
                ),
              if (widget.provider.address?.trim().isNotEmpty == true)
                AarastStatusPill(
                  label: widget.provider.address!.trim(),
                  icon: LucideIcons.building2,
                  color: AppTheme.gold,
                  backgroundColor: AppTheme.ivory,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({
    required this.services,
    required this.onRequestQuote,
  });

  final List<MarketplaceService> services;
  final ValueChanged<MarketplaceService> onRequestQuote;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'الخدمات المتاحة',
            icon: LucideIcons.wand,
          ),
          const SizedBox(height: 12),
          if (services.isEmpty)
            const AarastEmptyState(
              icon: LucideIcons.wand,
              title: 'لا توجد خدمات منشورة',
              message: 'سيظهر هنا كتالوج خدمات المورد عند إضافته.',
            )
          else
            for (final service in services) ...[
              _ServiceTile(service: service, onRequestQuote: onRequestQuote),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onRequestQuote});

  final MarketplaceService service;
  final ValueChanged<MarketplaceService> onRequestQuote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.ivory,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.sparkles, color: AppTheme.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _priceText(service.basePrice, service.currency),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'طلب عرض لهذه الخدمة',
            onPressed: () => onRequestQuote(service),
            icon: const Icon(LucideIcons.chevronLeft),
          ),
        ],
      ),
    );
  }
}

class _PackagesSection extends StatelessWidget {
  const _PackagesSection({required this.packages});

  final List<ProviderPackage> packages;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'الباقات المتاحة',
            icon: LucideIcons.package,
          ),
          const SizedBox(height: 12),
          if (packages.isEmpty)
            const Text(
              'لا توجد باقات منشورة حاليًا.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            )
          else
            for (final item in packages) ...[
              _PackageTile(item: item),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({required this.item});

  final ProviderPackage item;

  @override
  Widget build(BuildContext context) {
    final features = _packageFeatures(item.items);
    final hasPrice = item.price?.trim().isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.goldSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.burgundySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.gift,
                  color: AppTheme.burgundy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (item.serviceTitle?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.serviceTitle!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppTheme.muted),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasPrice)
                Text(
                  _priceText(item.price, item.currency),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          if (item.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              item.description!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.muted, height: 1.4),
            ),
          ],
          if (features.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final feature in features) _FeatureChip(feature)],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.check, size: 13, color: AppTheme.gold),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.reviews});

  final List<ProviderReview> reviews;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(title: 'التقييمات', icon: LucideIcons.star),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            const Text(
              'لا توجد تقييمات بعد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            )
          else
            for (final review in reviews.take(4)) ...[
              _ReviewTile(review: review),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ProviderReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.star, color: AppTheme.gold, size: 18),
              const SizedBox(width: 4),
              Text(
                '${review.rating}/5',
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.userName ?? 'مستخدم أعرست',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ),
            ],
          ),
          if (review.comment?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!.trim(),
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppTheme.muted, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

List<String> _packageFeatures(String? items) {
  if (items == null) return const [];
  return items
      .split('\n')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .take(8)
      .toList();
}

String _priceText(String? value, String? currency) {
  final clean = value?.trim();
  if (clean == null || clean.isEmpty) return 'السعر غير منشور';
  final amount = num.tryParse(clean.replaceAll(',', ''));
  final formatted = amount == null ? clean : _formatMoney(amount);
  return '$formatted ${currencyLabelAr(currency)}';
}

String _formatMoney(num value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${rounded < 0 ? '-' : ''}$buffer';
}
