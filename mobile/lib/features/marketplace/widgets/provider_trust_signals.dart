import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_journey_profile.dart';
import '../../../core/l10n/aarast_text.dart';
import '../../../core/utils/arabic_count.dart';
import '../data/marketplace_api.dart';
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

/// f03 «يردّ عادة خلال ساعتين», said only when he answered 80% of his
/// requests or more (2026-11-26 review: a fast answer to half of them is no
/// fast answer); below that «يردّ على 60% من الطلبات». Null with no history
/// to judge by.
String? providerRespondsLabel(ProviderResponsiveness? responsiveness) {
  if (responsiveness == null || responsiveness.sampleSize == 0) return null;
  if (!responsiveness.saysResponseTime) {
    return aarastText.providersRespondsShare(responsiveness.answeredPercent);
  }
  final hours = responsiveness.typicalResponseHours!;
  if (hours < 24) {
    return aarastText.providersRespondsHours(hours < 1 ? 1 : hours);
  }
  return aarastText.providersRespondsDays((hours / 24).ceil());
}

/// f03 «آخر تحديث للسعر قبل 3 أسابيع»; an old price also asks to confirm it.
String priceAgeLine(
  DateTime updatedAt,
  DateTime now, {
  JourneyProfile profile = JourneyProfile.groom,
}) {
  final line = 'آخر تحديث للسعر ${_ago(updatedAt, now)}';
  return now.difference(updatedAt) > providerPriceStaleAfter
      ? '$line · ${profile.say('تأكد منه لما تطلب العرض', 'تأكدي منه لما تطلبين العرض')}'
      : line;
}

String _ago(DateTime then, DateTime now) {
  final days = now.difference(then).inDays;
  if (days < 1) return 'اليوم';
  if (days == 1) return 'أمس';
  if (days < 14) return 'قبل ${arabicDays(days)}';
  if (days < 30) {
    final weeks = days ~/ 7;
    return 'قبل ${arabicCount(weeks, one: 'أسبوع', two: 'أسبوعين', few: 'أسابيع', many: 'أسبوعًا')}';
  }
  if (days >= 365) return 'قبل أكثر من سنة';
  final months = days ~/ 30;
  return 'قبل ${arabicCount(months, one: 'شهر', two: 'شهرين', few: 'شهور', many: 'شهر')}';
}

/// The same «يرد عادة …» line for a screen that only knows the provider's
/// id, as the conversation header (f06). The line is optional there, so a
/// failed read leaves it out instead of failing the screen.
Future<String?> providerRespondsLine(
  BuildContext context,
  String providerId,
) async {
  final api = context.read<MarketplaceApi>();
  try {
    final provider = await api.getProvider(providerId);
    return providerRespondsLabel(provider.responsiveness);
  } on Object {
    return null;
  }
}
