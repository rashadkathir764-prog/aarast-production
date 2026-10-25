import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../models/aarast_notification.dart';

/// The line under a notice's title (b08: «500,000 ر.ي · الجمعة 30 أكتوبر»).
///
/// The server never writes an amount in a notice's words (B-38): a money
/// reminder carries it in `data` (`amount`, `currency`), and only for a
/// reader with money rights. The phone writes it the app's one way
/// ([formatCompactMoney]) and leaves it out under «أخفِ المبالغ», a setting
/// that lives on this phone only.
String notificationLine(
  AarastNotification notification, {
  required bool hideAmounts,
}) {
  final body = notification.body.trim();
  final amount = num.tryParse(notification.data?['amount']?.toString() ?? '');
  if (hideAmounts || amount == null) return body;
  final currency =
      notification.data?['currency']?.toString() ?? defaultCurrencyCode;
  final money = formatCompactMoney(amount, currencyCode: currency);
  return body.isEmpty ? money : '$money · $body';
}
