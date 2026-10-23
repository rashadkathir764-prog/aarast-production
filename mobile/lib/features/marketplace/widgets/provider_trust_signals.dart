import '../models/marketplace_models.dart';

/// A price older than this is flagged so the customer confirms it first.
const providerPriceStaleAfter = Duration(days: 90);

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

/// f03 «يرد عادة خلال ساعتين», only from answered requests; null when the
/// provider has none to judge by.
String? providerRespondsLabel(ProviderResponsiveness? responsiveness) {
  final hours = responsiveness?.typicalResponseHours;
  if (responsiveness == null || responsiveness.sampleSize == 0) return null;
  if (hours == null) return null;
  return 'يرد عادة ${_withinLabel(hours)}';
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
  return 'خلال $days يوم';
}

/// f03 «آخر تحديث للسعر قبل 3 أسابيع»; an old price also asks to confirm it.
String priceAgeLine(DateTime updatedAt, DateTime now) {
  final line = 'آخر تحديث للسعر ${_ago(updatedAt, now)}';
  return now.difference(updatedAt) > providerPriceStaleAfter
      ? '$line · تأكد منه لما تطلب العرض'
      : line;
}

String _ago(DateTime then, DateTime now) {
  final days = now.difference(then).inDays;
  if (days < 1) return 'اليوم';
  if (days == 1) return 'أمس';
  if (days == 2) return 'قبل يومين';
  if (days <= 10) return 'قبل $days أيام';
  if (days < 14) return 'قبل $days يوم';
  if (days < 30) {
    final weeks = days ~/ 7;
    return weeks == 2 ? 'قبل أسبوعين' : 'قبل $weeks أسابيع';
  }
  if (days >= 365) return 'قبل أكثر من سنة';
  final months = days ~/ 30;
  if (months == 1) return 'قبل شهر';
  if (months == 2) return 'قبل شهرين';
  if (months <= 10) return 'قبل $months شهور';
  return 'قبل $months شهر';
}
