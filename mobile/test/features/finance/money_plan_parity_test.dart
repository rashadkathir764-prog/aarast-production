import 'dart:convert';
import 'dart:io';

import 'package:aarast_mobile/features/finance/data/finance_local_money_plan.dart';
import 'package:flutter_test/flutter_test.dart';

// A plan kept on the phone works its money out on the phone (D103-D109);
// an account plan reads the server's. Both must say the same thing on the
// same plan: the server writes its answers for fixed plans
// (backend `npm run contracts:money-plan`), and the phone's copy is held to
// them here, field by field.

Object? _normalized(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _normalized(entry.value),
    };
  }
  if (value is List) return [for (final item in value) _normalized(item)];
  if (value is String) {
    // An amount is compared as a number: «1700» and «1700.00» are one.
    final number = num.tryParse(value);
    if (number != null && RegExp(r'^-?\d+(\.\d+)?$').hasMatch(value)) {
      return (number * 100).round();
    }
  }
  return value;
}

void main() {
  final fixtures =
      jsonDecode(
            File('test/fixtures/money_plan_fixtures.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final scenarios = (fixtures['scenarios'] as List).cast<Map<String, dynamic>>();

  test('the fixtures hold several plans', () {
    expect(scenarios.length, greaterThanOrEqualTo(6));
  });

  for (final scenario in scenarios) {
    test('the phone answers «${scenario['name']}» as the server does', () {
      final input = Map<String, dynamic>.from(scenario['input'] as Map);
      final phone = _normalized(localMoneyPlan(input)) as Map;
      final server = _normalized(scenario['answer']) as Map;
      for (final key in server.keys) {
        expect(phone[key], server[key], reason: '«${scenario['name']}»: $key');
      }
      expect(phone.keys.toSet(), server.keys.toSet());
    });
  }
}
