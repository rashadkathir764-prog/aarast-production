import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../models/marketplace_models.dart';

class ProviderDetailsSections extends StatefulWidget {
  const ProviderDetailsSections({
    required this.provider,
    required this.services,
    required this.packages,
    required this.reviews,
    required this.onRequestQuote,
    this.servicesErrorMessage,
    this.packagesErrorMessage,
    this.reviewsErrorMessage,
    this.isRetryingDetails = false,
    this.onRetryDetails,
    super.key,
  });

  final MarketplaceProvider provider;
  final List<MarketplaceService> services;
  final List<ProviderPackage> packages;
  final List<ProviderReview> reviews;
  final ValueChanged<MarketplaceService> onRequestQuote;
  final String? servicesErrorMessage;
  final String? packagesErrorMessage;
  final String? reviewsErrorMessage;
  final bool isRetryingDetails;
  final VoidCallback? onRetryDetails;

  @override
  State<ProviderDetailsSections> createState() =>
      _ProviderDetailsSectionsState();
}

class _ProviderDetailsSectionsState extends State<ProviderDetailsSections> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(
          _ServicesSection(
            services: widget.services,
            onRequestQuote: widget.onRequestQuote,
            errorMessage: widget.servicesErrorMessage,
            isRetrying: widget.isRetryingDetails,
            onRetry: widget.onRetryDetails,
          ),
        ),
        const _SectionDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showMore = !_showMore),
            icon: Icon(
              _showMore ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              size: 18,
            ),
            label: Text(
              _showMore
                  ? 'إخفاء التفاصيل الإضافية'
                  : 'الباقات والتفاصيل والتقييمات',
            ),
          ),
        ),
        AnimatedSize(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AarastV3Motion.standard,
          curve: AarastV3Motion.curve,
          alignment: Alignment.topCenter,
          child: !_showMore
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionDivider(),
                    _section(
                      _PackagesSection(
                        packages: widget.packages,
                        errorMessage: widget.packagesErrorMessage,
                        isRetrying: widget.isRetryingDetails,
                        onRetry: widget.onRetryDetails,
                      ),
                    ),
                    const _SectionDivider(),
                    _section(_AboutSection(provider: widget.provider)),
                    const _SectionDivider(),
                    _section(
                      _ReviewsSection(
                        reviews: widget.reviews,
                        errorMessage: widget.reviewsErrorMessage,
                        isRetrying: widget.isRetryingDetails,
                        onRetry: widget.onRetryDetails,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

Widget _section(Widget child) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
  child: child,
);

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Divider(),
    );
  }
}

class _EditorialSectionHeader extends StatelessWidget {
  const _EditorialSectionHeader({
    required this.title,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.brandMuted,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppTheme.brand),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatefulWidget {
  const _AboutSection({required this.provider});

  final MarketplaceProvider provider;

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final description = widget.provider.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;
    final text = hasDescription
        ? description
        : 'لا توجد نبذة مفصلة بعد. يمكنك طلب عرض سعر لمعرفة التفاصيل المناسبة لخطتك.';
    final canExpand = hasDescription && description.length > 150;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EditorialSectionHeader(
          title: 'نبذة عن المورد',
          icon: LucideIcons.info,
        ),
        const SizedBox(height: 14),
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
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.75,
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
                minimumSize: const Size(0, 34),
              ),
              child: Text(_expanded ? 'عرض أقل' : 'عرض المزيد'),
            ),
          ),
        if (_hasContactDetails(widget.provider)) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.provider.phone?.trim().isNotEmpty == true)
                _ContactDetail(
                  label:
                      PhoneNumberUtils.directionalDisplay(
                        widget.provider.phone,
                      ) ??
                      widget.provider.phone!.trim(),
                  icon: LucideIcons.phone,
                ),
              if (widget.provider.address?.trim().isNotEmpty == true)
                _ContactDetail(
                  label: widget.provider.address!.trim(),
                  icon: LucideIcons.mapPin,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ContactDetail extends StatelessWidget {
  const _ContactDetail({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.brand),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
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
    this.errorMessage,
    this.isRetrying = false,
    this.onRetry,
  });

  final List<MarketplaceService> services;
  final ValueChanged<MarketplaceService> onRequestQuote;
  final String? errorMessage;
  final bool isRetrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EditorialSectionHeader(
          title: 'الخدمات المتاحة',
          subtitle: 'اختر خدمة لتبدأ طلب عرض السعر بالتفاصيل الصحيحة.',
          icon: LucideIcons.sparkles,
        ),
        const SizedBox(height: 14),
        if (errorMessage != null) ...[
          _EditorialRetry(
            message: errorMessage!,
            isRetrying: isRetrying,
            onRetry: onRetry,
          ),
          const SizedBox(height: 12),
        ],
        if (services.isEmpty && errorMessage == null)
          const _EditorialEmpty(
            icon: LucideIcons.wand,
            title: 'لا توجد خدمات منشورة',
            message: 'سيظهر هنا كتالوج خدمات المورد عند إضافته.',
          )
        else
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                for (final service in services)
                  _ServiceLine(
                    service: service,
                    onRequestQuote: onRequestQuote,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ServiceLine extends StatelessWidget {
  const _ServiceLine({required this.service, required this.onRequestQuote});

  final MarketplaceService service;
  final ValueChanged<MarketplaceService> onRequestQuote;

  @override
  Widget build(BuildContext context) {
    final description = service.description?.trim();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _priceText(service.basePrice, service.currency),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brand,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'طلب عرض لهذه الخدمة',
            child: Material(
              color: AppTheme.surfaceRaised,
              shape: CircleBorder(
                side: BorderSide(color: AppTheme.border.withValues(alpha: 0.9)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onRequestQuote(service),
                child: const SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    LucideIcons.arrowLeft,
                    size: 19,
                    color: AppTheme.brand,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackagesSection extends StatelessWidget {
  const _PackagesSection({
    required this.packages,
    this.errorMessage,
    this.isRetrying = false,
    this.onRetry,
  });

  final List<ProviderPackage> packages;
  final String? errorMessage;
  final bool isRetrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EditorialSectionHeader(
          title: 'الباقات المتاحة',
          subtitle: 'مرجع للمقارنة فقط؛ يتأكد المحتوى والسعر عبر طلب العرض.',
          icon: LucideIcons.package,
        ),
        const SizedBox(height: 14),
        if (errorMessage != null) ...[
          _EditorialRetry(
            message: errorMessage!,
            isRetrying: isRetrying,
            onRetry: onRetry,
          ),
          const SizedBox(height: 12),
        ],
        if (packages.isEmpty && errorMessage == null)
          const _EditorialEmpty(
            icon: LucideIcons.packageOpen,
            title: 'لا توجد باقات منشورة حاليًا.',
            message: 'يمكنك طلب عرض سعر للخدمة المناسبة مباشرة.',
          )
        else
          for (var index = 0; index < packages.length; index++) ...[
            _PackageBlock(item: packages[index]),
            if (index != packages.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _PackageBlock extends StatelessWidget {
  const _PackageBlock({required this.item});

  final ProviderPackage item;

  @override
  Widget build(BuildContext context) {
    final features = _packageFeatures(item.items);
    final description = item.description?.trim();
    final serviceTitle = item.serviceTitle?.trim();
    final hasPrice = item.price?.trim().isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.brandMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (serviceTitle != null && serviceTitle.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              serviceTitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
          if (hasPrice) ...[
            const SizedBox(height: 9),
            Text(
              _priceText(item.price, item.currency),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.brand,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
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
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.check, size: 13, color: AppTheme.brand),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.reviews,
    this.errorMessage,
    this.isRetrying = false,
    this.onRetry,
  });

  final List<ProviderReview> reviews;
  final String? errorMessage;
  final bool isRetrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _EditorialSectionHeader(
          title: 'التقييمات',
          icon: LucideIcons.star,
        ),
        const SizedBox(height: 14),
        if (errorMessage != null) ...[
          _EditorialRetry(
            message: errorMessage!,
            isRetrying: isRetrying,
            onRetry: onRetry,
          ),
          const SizedBox(height: 12),
        ],
        if (reviews.isEmpty && errorMessage == null)
          const _EditorialEmpty(
            icon: LucideIcons.messageSquare,
            title: 'لا توجد تقييمات بعد.',
            message: 'ستظهر هنا تجارب العملاء عند توفرها.',
          )
        else
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                for (final review in reviews.take(4))
                  _ReviewLine(review: review),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.review});

  final ProviderReview review;

  @override
  Widget build(BuildContext context) {
    final comment = review.comment?.trim();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.star, color: AppTheme.focus, size: 17),
              const SizedBox(width: 5),
              Text(
                '${review.rating}/5',
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  review.userName ?? 'مستخدم أعرست',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorialRetry extends StatelessWidget {
  const _EditorialRetry({
    required this.message,
    required this.isRetrying,
    this.onRetry,
  });

  final String message;
  final bool isRetrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('provider-details-section-error'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تعذر تحديث هذا القسم',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.danger,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: isRetrying ? null : onRetry,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorialEmpty extends StatelessWidget {
  const _EditorialEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.45,
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

bool _hasContactDetails(MarketplaceProvider provider) {
  return provider.phone?.trim().isNotEmpty == true ||
      provider.address?.trim().isNotEmpty == true;
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
