import 'package:flutter_test/flutter_test.dart';
import 'package:aarast_mobile/features/finance/models/financial_commitment.dart';

void main() {
  test('payment ledger contract preserves reversal and audit links', () {
    final payment = FinancialPaymentRecord.fromJson({
      'id': 'payment-1',
      'weddingPlanId': 'plan-1',
      'financialCommitmentId': 'commitment-1',
      'budgetCategoryId': 'category-1',
      'title': 'دفعة',
      'amount': '200.00',
      'paidAt': '2026-07-10T00:00:00.000Z',
      'entryType': 'PAYMENT',
      'financialInstallmentId': 'installment-1',
      'reversedById': null,
      'reversible': true,
    });

    expect(payment.isReversal, isFalse);
    expect(payment.signedAmount, '200.00');
    expect(payment.financialInstallmentId, 'installment-1');
    expect(payment.reversible, isTrue);
  });

  test('reversal is displayed as a negative immutable movement', () {
    final reversal = FinancialPaymentRecord.fromJson({
      'id': 'reversal-1',
      'weddingPlanId': 'plan-1',
      'financialCommitmentId': 'commitment-1',
      'budgetCategoryId': 'category-1',
      'title': 'عكس: دفعة',
      'amount': '200.00',
      'paidAt': '2026-07-10T00:00:00.000Z',
      'entryType': 'REVERSAL',
      'reversalOfId': 'payment-1',
      'reversible': false,
    });

    expect(reversal.isReversal, isTrue);
    expect(reversal.signedAmount, '-200.00');
    expect(reversal.reversalOfId, 'payment-1');
    expect(reversal.reversible, isFalse);
  });
}
