import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:flutter_test/flutter_test.dart';

// RA-MO-171 (D86): «من وين» summed its sections on the phone and took its
// head from the server's summary; offline, a source added since showed in
// one figure and not the other.

void main() {
  const summary = MoneyFundingSummary(
    received: '1800000',
    spent: '400000',
    loanRepaid: '200000',
    availableCash: '1200000',
  );

  test('without a list on the phone the head is the summary\'s', () {
    final head = summary.headOn(null);
    expect(head.received, 1800000);
    expect(head.cash, 1200000);
  });

  test('with the list, the head sums what its sections sum', () {
    // A gift of 300,000 added offline: on the list, not in the summary.
    final head = summary.headOn(2100000);
    expect(head.received, 2100000);
    expect(head.cash, 1500000);
  });

  test('«معك» never goes below zero', () {
    expect(summary.headOn(100000).cash, 0);
  });
}
