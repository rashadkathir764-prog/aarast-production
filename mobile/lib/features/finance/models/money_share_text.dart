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
/// as such. Every figure is the server's.
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
  final owner = bridePlan ? 'العروسة' : 'العريس';
  final lines = <String>['ملخص ميزانية «${planTitle.trim()}»', ''];

  if (hideAmounts) {
    if (total > 0) {
      lines.add('• استُخدم ${_percent(committed, total)}٪ من الميزانية');
    }
    if (committed > 0) {
      lines.add('• دُفع ${_percent(paid, committed)}٪ من التكاليف المسجلة');
    }
    lines.add('• عدد التكاليف المسجلة: ${budget.count}');
  } else {
    if (summary.hasBudget) lines.add('• الميزانية: ${money(budget.total)}');
    lines.add(
      total > 0
          ? '• الملتزم به: ${money(budget.confirmedCost)} (${_percent(committed, total)}٪ من الميزانية)'
          : '• الملتزم به: ${money(budget.confirmedCost)}',
    );
    lines.add('• المدفوع: ${money(budget.paid)}');
    if (moneyValue(budget.paidByOthers) > 0) {
      lines.add('• منه دفعه غير $owner: ${money(budget.paidByOthers)}');
    }
    lines.add('• المتبقي للدفع: ${money(budget.outstanding)}');
    if (budget.remaining != null) {
      lines.add('• المتبقي من الميزانية: ${money(budget.remaining)}');
    }
  }

  // The groom's mahr is a cost he shares like any other, on its own line;
  // the bride's is money coming to her, private like every source.
  final mahr = summary.mahr;
  if (mahr != null && mahr.side == MahrSide.pays) {
    lines.add(
      hideAmounts
          ? '• المهر (خارج الميزانية): سُلّم ${_percent(moneyValue(mahr.settled), moneyValue(mahr.total))}٪ منه'
          : '• المهر (خارج الميزانية): ${money(mahr.total)}، سُلّم منه ${money(mahr.settled)}',
    );
  }

  final biggest = [...summary.weddingCategories]
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
