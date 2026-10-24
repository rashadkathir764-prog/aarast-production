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
