import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:flutter_test/flutter_test.dart';

PaymentSchedule _reminder(
  String id,
  String costId, {
  required String amount,
  String? amountDue,
  String? costRemaining,
}) => PaymentSchedule(
  id: id,
  costId: costId,
  amount: amount,
  amountDue: amountDue,
  costRemaining: costRemaining,
  dueDate: DateTime.utc(2026, 12, 1),
  status: 'PENDING',
);

void main() {
  // RA-BE-53: an agreement of 1,000,000 with 800,000 paid owes 200,000. Its
  // two reminders of 500,000 each ask for 200,000 (each up to what is left),
  // and together they are 200,000, not 400,000.
  test('two reminders of one agreement never add up past what it owes', () {
    final total = dueSchedulesTotal([
      _reminder(
        'a',
        'hall',
        amount: '500000',
        amountDue: '200000',
        costRemaining: '200000',
      ),
      _reminder(
        'b',
        'hall',
        amount: '500000',
        amountDue: '200000',
        costRemaining: '200000',
      ),
    ]);
    expect(total, 200000);
  });

  test('reminders under what their agreement owes add up as they are', () {
    final total = dueSchedulesTotal([
      _reminder(
        'a',
        'hall',
        amount: '50000',
        amountDue: '50000',
        costRemaining: '200000',
      ),
      _reminder(
        'b',
        'hall',
        amount: '70000',
        amountDue: '70000',
        costRemaining: '200000',
      ),
      _reminder(
        'c',
        'photos',
        amount: '30000',
        amountDue: '30000',
        costRemaining: '30000',
      ),
    ]);
    expect(total, 150000);
  });

  test('each agreement is capped on its own', () {
    final total = dueSchedulesTotal([
      _reminder(
        'a',
        'hall',
        amount: '150000',
        amountDue: '150000',
        costRemaining: '200000',
      ),
      _reminder(
        'b',
        'hall',
        amount: '150000',
        amountDue: '150000',
        costRemaining: '200000',
      ),
      _reminder(
        'c',
        'photos',
        amount: '30000',
        amountDue: '30000',
        costRemaining: '30000',
      ),
    ]);
    expect(total, 230000);
  });

  test('a reminder from an older server counts at what it asks for', () {
    final total = dueSchedulesTotal([
      _reminder('a', 'hall', amount: '500000', amountDue: '200000'),
      _reminder('b', 'hall', amount: '500000', amountDue: '200000'),
    ]);
    expect(total, 400000);
  });

  test('the copy kept on the phone carries what its agreement owes', () {
    final kept = _reminder(
      'a',
      'hall',
      amount: '500000',
    ).withRemaining('200000');
    expect(kept.amountDue, '200000');
    expect(kept.costRemaining, '200000');
  });
}
