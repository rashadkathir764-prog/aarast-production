import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful quote submission returns without a full success screen', () {
    final source = File(
      'lib/features/marketplace/screens/quote_request_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('class _QuoteSentState')));
    expect(source, isNot(contains('setState(() => _sent = true)')));
    expect(source, contains("showSnackBar"));
    expect(source, contains("context.pop(true)"));
  });
}
