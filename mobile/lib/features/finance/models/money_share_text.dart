import '../../../core/utils/money_formatters.dart';
import 'money_summary.dart';
import 'wedding_cost.dart' show moneyValue;

/// A budget summary to send on WhatsApp (V1 checklist 4.16): only what the
/// sender sees on the money screen, never the funding sources or loans
/// (the owner's private money, 4.3). With [hideAmounts] it shares shares
/// of the budget instead of figures.
String moneyShareText(
  MoneySummary summary, {
  required String planTitle,
  required bool hideAmounts,
}) {
  final currency = summary.currency;
  String money(Object? value) =>
      compactMoneyParts(moneyValue(value), currencyCode: currency).plainText;
  final budget = summary.hasBudget ? moneyValue(summary.budget.total) : 0;
  final committed = moneyValue(summary.costs.total);
  final paid = moneyValue(summary.costs.paid);
  final lines = <String>['ملخص ميزانية «${planTitle.trim()}»', ''];

  if (hideAmounts) {
    if (budget > 0) {
      lines.add('• استُخدم ${_percent(committed, budget)}٪ من الميزانية');
    }
    if (committed > 0) {
      lines.add('• دُفع ${_percent(paid, committed)}٪ من التكاليف المسجلة');
    }
    lines.add('• عدد التكاليف المسجلة: ${summary.costs.count}');
  } else {
    if (summary.hasBudget) lines.add('• الميزانية: ${money(summary.budget.total)}');
    lines.add(
      budget > 0
          ? '• الملتزم به: ${money(summary.costs.total)} (${_percent(committed, budget)}٪ من الميزانية)'
          : '• الملتزم به: ${money(summary.costs.total)}',
    );
    lines.add('• المدفوع: ${money(summary.costs.paid)}');
    lines.add('• المتبقي للدفع: ${money(summary.costs.outstanding)}');
    if (summary.budget.remaining != null) {
      lines.add('• المتبقي من الميزانية: ${money(summary.budget.remaining)}');
    }
  }

  final biggest = [...summary.categories]
    ..removeWhere((category) => moneyValue(category.confirmedCost) <= 0)
    ..sort(
      (left, right) => moneyValue(right.confirmedCost)
          .compareTo(moneyValue(left.confirmedCost)),
    );
  if (biggest.isNotEmpty) {
    lines
      ..add('')
      ..add('أكبر البنود:');
    for (final category in biggest.take(5)) {
      lines.add(
        hideAmounts
            ? '• ${category.name}'
            : '• ${category.name}: ${money(category.confirmedCost)} (مدفوع ${money(category.paid)})',
      );
    }
  }
  final exceeded = summary.exceededCategories;
  if (exceeded.isNotEmpty) {
    lines
      ..add('')
      ..add('⚠ تجاوزت المخصص: ${exceeded.map((item) => item.name).join('، ')}');
  }
  lines
    ..add('')
    ..add('— من تطبيق اعّرست');
  return lines.join('\n');
}

int _percent(num part, num whole) =>
    whole <= 0 ? 0 : (part / whole * 100).round();
