import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceService, ProviderPackage, ProviderReview;
import 'provider_request_parts.dart' show providerGroupedAmount;

/// «قبل أسبوعين»: how long ago, in the words p36 and p35 use.
String providerAgoLabel(DateTime then, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final local = then.toLocal();
  final days = DateTime(
    clock.year,
    clock.month,
    clock.day,
  ).difference(DateTime(local.year, local.month, local.day)).inDays;
  if (days < 1) return 'اليوم';
  if (days == 1) return 'أمس';
  if (days < 14) {
    return 'قبل ${arabicCount(days, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}';
  }
  if (days < 30) {
    final weeks = days ~/ 7;
    return 'قبل ${arabicCount(weeks, one: 'أسبوع', two: 'أسبوعين', few: 'أسابيع', many: 'أسبوع')}';
  }
  if (days >= 365) return 'قبل أكثر من سنة';
  final months = days ~/ 30;
  return 'قبل ${arabicCount(months, one: 'شهر', two: 'شهرين', few: 'شهور', many: 'شهر')}';
}

/// p35's «الظهور المميز» line (B-43): «مميز لين 31 ديسمبر» while the team's
/// recorded placement runs, «يبدأ 1 يناير · لين 31 مارس» for one booked
/// later, or how to ask for it. `endsAt` starts the day after the last one
/// covered, in Sana'a time, and is the end of his run of renewals (the
/// server joins back-to-back ones). It is read against the clock when shown:
/// a profile loaded before the end does not keep saying «مميز» after it.
String providerFeaturedLine({
  DateTime? startsAt,
  DateTime? endsAt,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  if (startsAt == null || endsAt == null || !endsAt.isAfter(clock)) {
    return 'ظهور عادي · تبي تطلع أول؟ كلّم فريق اعّرست';
  }
  final lastDay = formatArabicDayMonth(
    _sanaaDay(endsAt.subtract(const Duration(milliseconds: 1))),
  );
  if (startsAt.isAfter(clock)) {
    return 'يبدأ ${formatArabicDayMonth(_sanaaDay(startsAt))} · لين $lastDay';
  }
  return 'مميز لين $lastDay';
}

DateTime _sanaaDay(DateTime at) {
  final sanaa = at.toUtc().add(const Duration(hours: 3));
  return DateTime(sanaa.year, sanaa.month, sanaa.day);
}

/// «3 ساعات», «يومين»: a reply time in hours, as p39 reads it.
String providerHoursLabel(int hours) {
  if (hours < 24) {
    return arabicCount(
      hours < 1 ? 1 : hours,
      one: 'ساعة',
      two: 'ساعتين',
      few: 'ساعات',
      many: 'ساعة',
    );
  }
  final days = (hours / 24).ceil();
  return arabicCount(days, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم');
}

/// «4.7 · 38 تقييم».
String providerRatingLabel(double average, int count) =>
    '${average.toStringAsFixed(1)} · ${arabicCount(count, one: 'تقييم واحد', two: 'تقييمين', few: 'تقييمات', many: 'تقييم')}';

/// The photos customers see on his page: every service image (F14 has no
/// portfolio of its own).
int providerPhotoCount(List<MarketplaceService> services) =>
    services.fold(0, (sum, service) => sum + service.images.length);

/// «3 خدمات · باقتين · من 350,000»: what he offers and the lowest price
/// among the active ones; what to add first when he has none.
String providerServicesLine(
  List<MarketplaceService> services,
  List<ProviderPackage> packages,
) {
  if (services.isEmpty && packages.isEmpty) return 'أضف خدماتك وأسعارك';
  num? lowest;
  for (final price in [
    for (final service in services)
      if (service.isActive) service.basePrice,
    for (final package in packages)
      if (package.isActive) package.price,
  ]) {
    final value = num.tryParse(price?.trim() ?? '');
    if (value != null && value > 0 && (lowest == null || value < lowest)) {
      lowest = value;
    }
  }
  return [
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
    if (lowest != null) 'من ${providerGroupedAmount('$lowest')}',
  ].join(' · ');
}

/// «الأسعار بريال صنعاء»: the currency his prices are in, when they share
/// one.
String? providerPricesCurrencyLine(
  List<MarketplaceService> services,
  List<ProviderPackage> packages,
) {
  final currencies = {
    for (final service in services)
      if (service.basePrice?.trim().isNotEmpty == true)
        (service.currency ?? defaultCurrencyCode).toUpperCase(),
    for (final package in packages)
      if (package.price?.trim().isNotEmpty == true)
        (package.currency ?? defaultCurrencyCode).toUpperCase(),
  };
  if (currencies.length != 1) return null;
  return 'الأسعار ب${currencySpokenLabelAr(currencies.single)}';
}

/// p35 «التقييمات»: the published reviews, as customers read them on his
/// page (D35), and how many are not shown. Each card is p27's: the name,
/// the stars and the words in quotes. The server keeps no occasion, tags,
/// reply or report (F15; B-09, B-28), so the card says when the review was
/// written instead of «الزفة · 21 يناير», and no reply box or «بلّغ عنه» is
/// offered.
class ProviderReviewsSheet extends StatelessWidget {
  const ProviderReviewsSheet({required this.all, super.key});

  final List<ProviderReview> all;

  @override
  Widget build(BuildContext context) {
    final reviews = [
      for (final review in all)
        if (review.isPublished) review,
    ];
    final hidden = all.length - reviews.length;
    return JourneySheetBody(
      title: 'التقييمات',
      subtitle: [
        reviews.isEmpty
            ? 'ما فيه تقييم منشور لسا'
            : '${arabicCount(reviews.length, one: 'تقييم واحد', two: 'تقييمين', few: 'تقييمات', many: 'تقييم')} في ملفك',
        // Hidden by the admin or waiting for review (D35).
        if (hidden == 1) 'وتقييم ما يظهر للعرسان',
        if (hidden > 1)
          'و${arabicCount(hidden, one: '', two: 'تقييمين', few: 'تقييمات', many: 'تقييم')} ما تظهر للعرسان',
      ].join('، '),
      children: [
        if (reviews.isEmpty)
          const JourneyNote(
            icon: LucideIcons.star,
            text: 'التقييمات توصل من العرسان بعد أعراسهم، وتظهر هنا وفي ملفك.',
          )
        else
          for (final review in reviews) ...[
            ProviderReviewCard(review: review),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

/// p27's review card: «محمد» and five stars, when it was written, and the
/// words in quotes.
class ProviderReviewCard extends StatelessWidget {
  const ProviderReviewCard({required this.review, this.now, super.key});

  final ProviderReview review;

  /// The clock the age line reads; the device's when null.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final name = review.userName?.trim().isNotEmpty == true
        ? review.userName!.trim()
        : 'عريس من اعّرست';
    final comment = review.comment?.trim() ?? '';
    final written = review.createdAt;
    final rating = review.rating.clamp(0, 5);
    return JourneyBox(
      key: Key('provider-review-${review.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  name,
                  style: JourneyType.of(
                    JourneyType.lead,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                label: '$rating من 5',
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var star = 1; star <= 5; star++)
                        Icon(
                          LucideIcons.star,
                          size: 17,
                          color: star <= rating
                              ? AarastV3Color.saffron
                              : AarastV3Color.line,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (written != null)
            Text(
              providerAgoLabel(written, now: now),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '«$comment»',
              style: JourneyType.of(JourneyType.body, height: 1.6),
            ),
          ],
        ],
      ),
    );
  }
}
