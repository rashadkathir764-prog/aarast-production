import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../models/marketplace_models.dart';

/// A price older than this is flagged so the customer confirms it first.
const providerPriceStaleAfter = Duration(days: 90);

/// The provider card's trust line: how fast it answers, when its prices last
/// changed, and direct WhatsApp / map actions when the provider has them.
class ProviderTrustSignals extends StatelessWidget {
  const ProviderTrustSignals({
    required this.responsiveness,
    required this.pricesUpdatedAt,
    required this.now,
    this.onWhatsApp,
    this.onOpenMap,
    super.key,
  });

  final ProviderResponsiveness? responsiveness;
  final DateTime? pricesUpdatedAt;
  final DateTime now;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final responseLabel = responsiveness == null
        ? null
        : providerResponseLabel(responsiveness!);
    final priceDate = pricesUpdatedAt;
    final priceIsStale =
        priceDate != null &&
        now.difference(priceDate) > providerPriceStaleAfter;
    final hasLines = responseLabel != null || priceDate != null;
    final hasActions = onWhatsApp != null || onOpenMap != null;
    if (!hasLines && !hasActions) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (responseLabel != null)
            _TrustLine(
              key: const Key('provider-trust-response'),
              icon: LucideIcons.timer,
              label: responseLabel,
              color: AppTheme.textSecondary,
            ),
          if (priceDate != null)
            _TrustLine(
              key: const Key('provider-trust-price-date'),
              icon: priceIsStale
                  ? LucideIcons.alertTriangle
                  : LucideIcons.calendarCheck,
              label: priceIsStale
                  ? 'آخر تحديث للسعر ${priceFreshnessLabel(priceDate, now)} · تأكد منه عند طلب العرض'
                  : 'آخر تحديث للسعر ${priceFreshnessLabel(priceDate, now)}',
              color: priceIsStale ? AppTheme.danger : AppTheme.textSecondary,
            ),
          if (hasActions) ...[
            if (hasLines) const SizedBox(height: 10),
            Row(
              children: [
                if (onWhatsApp != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('provider-whatsapp-action'),
                      onPressed: onWhatsApp,
                      icon: const Icon(LucideIcons.messageCircle, size: 18),
                      label: const Text('واتساب'),
                    ),
                  ),
                if (onWhatsApp != null && onOpenMap != null)
                  const SizedBox(width: 10),
                if (onOpenMap != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('provider-map-action'),
                      onPressed: onOpenMap,
                      icon: const Icon(LucideIcons.mapPin, size: 18),
                      label: const Text('الموقع على الخريطة'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrustLine extends StatelessWidget {
  const _TrustLine({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The latest price change among the services, or null when none is priced.
DateTime? latestPriceUpdate(Iterable<MarketplaceService> services) {
  DateTime? latest;
  for (final service in services) {
    final stamp = service.priceUpdatedAt;
    if (stamp != null && (latest == null || stamp.isAfter(latest))) {
      latest = stamp;
    }
  }
  return latest;
}

String providerResponseLabel(ProviderResponsiveness responsiveness) {
  final hours = responsiveness.typicalResponseHours;
  final answered = 'ردّ على ${responsiveness.answeredPercent}٪ من الطلبات';
  if (hours == null) return 'لم يرد على طلبات العروض الأخيرة · $answered';
  return 'يرد عادة ${_withinLabel(hours)} · $answered';
}

String _withinLabel(int hours) {
  if (hours <= 1) return 'خلال ساعة';
  if (hours == 2) return 'خلال ساعتين';
  if (hours <= 10) return 'خلال $hours ساعات';
  if (hours < 24) return 'خلال $hours ساعة';
  final days = (hours / 24).ceil();
  if (days == 1) return 'خلال يوم';
  if (days == 2) return 'خلال يومين';
  if (days <= 10) return 'خلال $days أيام';
  return 'خلال $days يومًا';
}

String priceFreshnessLabel(DateTime updatedAt, DateTime now) {
  final days = now.difference(updatedAt).inDays;
  if (days < 1) return 'اليوم';
  if (days == 1) return 'أمس';
  if (days == 2) return 'منذ يومين';
  if (days <= 10) return 'منذ $days أيام';
  if (days < 30) return 'منذ $days يومًا';
  final months = days ~/ 30;
  if (days >= 365) return 'منذ أكثر من سنة';
  if (months == 1) return 'منذ شهر';
  if (months == 2) return 'منذ شهرين';
  if (months <= 10) return 'منذ $months أشهر';
  return 'منذ $months شهرًا';
}
