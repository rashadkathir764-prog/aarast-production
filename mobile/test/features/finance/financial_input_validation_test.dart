import 'package:aarast_mobile/features/finance/models/financial_input_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commitment total must be strictly positive', () {
    expect(validatePositiveMoney(''), isNotNull);
    expect(validatePositiveMoney('0'), isNotNull);
    expect(validatePositiveMoney('-1'), isNotNull);
    expect(validatePositiveMoney('1000'), isNull);
  });

  test('initial payment cannot exceed the commitment total', () {
    expect(validateInitialPayment('', totalRaw: '1000'), isNull);
    expect(validateInitialPayment('0', totalRaw: '1000'), isNull);
    expect(validateInitialPayment('1001', totalRaw: '1000'), isNotNull);
    expect(validateInitialPayment('1000', totalRaw: '1000'), isNull);
  });

  test('payment cannot exceed the selected remaining amount', () {
    expect(validatePaymentAmount('0', remaining: 500), isNotNull);
    expect(validatePaymentAmount('501', remaining: 500), isNotNull);
    expect(validatePaymentAmount('500', remaining: 500), isNull);
  });

  test(
    'budget setup needs a positive amount when no general budget exists',
    () {
      expect(
        hasUsableBudgetSetupAmount([null, '', '0'], hasGeneralBudget: false),
        isFalse,
      );
      expect(
        hasUsableBudgetSetupAmount([null, '', '0'], hasGeneralBudget: true),
        isTrue,
      );
      expect(
        hasUsableBudgetSetupAmount(['250000'], hasGeneralBudget: false),
        isTrue,
      );
    },
  );
}
