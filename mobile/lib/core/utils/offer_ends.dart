import 'arabic_count.dart';

/// «ينتهي بعد 6 أيام» for an offer open until [validUntil], counted in
/// calendar days from [now]'s day, so the chat and the requests agree;
/// «ينتهي اليوم» on its last day and null once it has ended.
String? offerEndsLabel(DateTime validUntil, DateTime now) {
  if (!validUntil.isAfter(now)) return null;
  final end = validUntil.toLocal();
  final today = now.toLocal();
  final days = DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (days <= 0) return 'ينتهي اليوم';
  return 'ينتهي بعد ${arabicDays(days)}';
}

/// The first of [deadlines] still ahead, said as [offerEndsLabel] does; null
/// when none is ahead. One already past does not hide the next one.
String? firstOfferEndsLabel(Iterable<DateTime?> deadlines, DateTime now) {
  final ahead = [
    for (final deadline in deadlines)
      if (deadline != null && deadline.isAfter(now)) deadline,
  ]..sort();
  return ahead.isEmpty ? null : offerEndsLabel(ahead.first.toLocal(), now);
}
