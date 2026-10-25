import 'arabic_date_formatter.dart';
import 'currency_label.dart';

/// One field an offer's new version changed (B-06): the server's
/// `{ field, from, to }`, values as text.
class QuoteOfferChange {
  const QuoteOfferChange({required this.field, this.from, this.to});

  factory QuoteOfferChange.fromJson(Map<String, dynamic> json) =>
      QuoteOfferChange(
        field: json['field']?.toString() ?? '',
        from: json['from']?.toString(),
        to: json['to']?.toString(),
      );

  /// `amount`, `currency`, `title`, `message` or `validUntil`.
  final String field;
  final String? from;
  final String? to;
}

/// «ايش تغيّر» in one line, for an offer at version 2 or later: the new
/// price first («السعر صار 520,000 ر.ي بدل 550,000»), else what else moved
/// «بنفس السعر». [own] is the provider reading his own offer; otherwise the
/// customer reads what «they» changed. Null on version 1 or without changes.
String? quoteOfferChangeLine({
  required List<QuoteOfferChange> changes,
  required String? currency,
  required bool own,
}) {
  if (changes.isEmpty) return null;
  QuoteOfferChange? find(String field) {
    for (final change in changes) {
      if (change.field == field) return change;
    }
    return null;
  }

  final amount = find('amount');
  if (amount != null) {
    final to = _grouped(amount.to);
    final from = _grouped(amount.from);
    if (to != null) {
      final label = currencyLabelAr(currency);
      return from == null
          ? 'السعر صار $to $label'
          : 'السعر صار $to $label بدل $from';
    }
  }
  final words = find('message') ?? find('title');
  if (words != null) {
    return own ? 'غيّرت التفاصيل بنفس السعر' : 'غيّروا التفاصيل بنفس السعر';
  }
  final until = find('validUntil');
  final day = DateTime.tryParse(until?.to ?? '');
  if (day != null) {
    final label = formatArabicDayMonth(day.toLocal());
    return own ? 'مدّدت العرض لين $label' : 'مدّدوا العرض لين $label';
  }
  return own ? 'عدّلت العرض' : 'عدّلوا العرض';
}

/// «520,000» from «520000»; null when the text is not an amount.
String? _grouped(String? raw) {
  final value = num.tryParse(raw?.replaceAll(',', '').trim() ?? '');
  if (value == null) return null;
  final digits = value.round().abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
