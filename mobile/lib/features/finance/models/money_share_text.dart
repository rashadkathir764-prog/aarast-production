import '../../../core/utils/money_formatters.dart';
import 'money_summary.dart';
import 'wedding_cost.dart' show moneyValue;

/// A budget summary to send on WhatsApp (V1 checklist 4.16): only what the
/// sender sees on the money screen, never the funding sources or loans
/// (the owner's private money, 4.3; the bride's mahr is one of them). With
/// [hideAmounts] it shares shares of the budget instead of figures.
///
/// D59: the budget lines are the wedding budget's own figures (the mahr is
/// outside it, C1), the groom's mahr is its own line and never one of the
/// biggest items, and what someone other than the plan's owner paid is said
/// as such. D105: the cost and what is left of the budget are by the
/// expected cost, as the tab says them. In the app's voice (RA-MO-42).
/// Every figure is the server's.
String moneyShareText(
  MoneySummary summary, {
  required String planTitle,
  required bool hideAmounts,
  bool bridePlan = false,
}) {
  final currency = summary.currency;
  final budget = summary.budget;
  String money(Object? value) =>
      compactMoneyParts(moneyValue(value), currencyCode: currency).plainText;
  final total = summary.hasBudget ? moneyValue(budget.total) : 0;
  final committed = moneyValue(budget.confirmedCost);
  final paid = moneyValue(budget.paid);
  // D105: the wedding's cost is what is expected of its items (agreements,
  // and the estimates they have not settled), as «البنود» says it; a
  // server before D105 sends only the agreements.
  final expected = summary.expected == null
      ? committed
      : moneyValue(summary.expected!.wedding.expected);
  final left = summary.expected?.budgetLeft ?? budget.remaining;
  final owner = bridePlan ? 'العروسة' : 'العريس';
  final lines = <String>['ملخص ميزانية «${planTitle.trim()}»', ''];

  if (hideAmounts) {
    if (total > 0) {
      lines.add(
        '• التكلفة المتوقعة ${_percent(expected, total)}٪ من الميزانية',
      );
    }
    if (committed > 0) {
      lines.add('• اندفع ${_percent(paid, committed)}٪ من الاتفاقات');
    }
    lines.add('• عدد الاتفاقات: ${budget.count}');
  } else {
    if (summary.hasBudget) lines.add('• الميزانية: ${money(budget.total)}');
    lines.add(
      total > 0
          ? '• تكلفة العرس المتوقعة: ${money(expected)} (${_percent(expected, total)}٪ من الميزانية)'
          : '• تكلفة العرس المتوقعة: ${money(expected)}',
    );
    if (expected != committed) {
      lines.add('• منها اتفاقات: ${money(committed)}');
    }
    lines.add('• اندفع: ${money(budget.paid)}');
    if (moneyValue(budget.paidByOthers) > 0) {
      lines.add('• منه دفعه غير $owner: ${money(budget.paidByOthers)}');
    }
    lines.add('• باقي على الاتفاقات: ${money(budget.outstanding)}');
    if (summary.hasBudget && left != null) {
      lines.add(
        moneyValue(left) < 0
            ? '• فوق الميزانية بـ ${money(-moneyValue(left))}'
            : '• باقي من الميزانية: ${money(left)}',
      );
    }
  }

  // The groom's mahr is a cost he shares like any other, on its own line;
  // the bride's is money coming to her, private like every source.
  final mahr = summary.mahr;
  if (mahr != null && mahr.side == MahrSide.pays) {
    lines.add(
      hideAmounts
          ? '• المهر (برا الميزانية): انسلّم ${_percent(moneyValue(mahr.settled), moneyValue(mahr.total))}٪ منه'
          : '• المهر (برا الميزانية): ${money(mahr.total)}، انسلّم منه ${money(mahr.settled)}',
    );
  }

  final biggest = [...summary.weddingCategories]
    ..removeWhere((category) => moneyValue(category.confirmedCost) <= 0)
    ..sort(
      (left, right) => moneyValue(
        right.confirmedCost,
      ).compareTo(moneyValue(left.confirmedCost)),
    );
  if (biggest.isNotEmpty) {
    lines
      ..add('')
      ..add('أكبر البنود:');
    for (final category in biggest.take(5)) {
      lines.add(
        hideAmounts
            ? '• ${category.name}'
            : '• ${category.name}: ${money(category.confirmedCost)} (اندفع ${money(category.paid)})',
      );
    }
  }
  final exceeded = summary.exceededCategories;
  if (exceeded.isNotEmpty) {
    lines
      ..add('')
      ..add(
        '⚠ فوق المخصص لها: ${exceeded.map((item) => item.name).join('، ')}',
      );
  }
  lines
    ..add('')
    ..add('— من تطبيق اعّرست');
  return lines.join('\n');
}

int _percent(num part, num whole) =>
    whole <= 0 ? 0 : (part / whole * 100).round();
