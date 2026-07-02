import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Plan Center truth contract', () {
    final source = File(
      '${_findMobileRoot()}lib/features/wedding_plans/screens/plan_center_screen.dart',
    ).readAsStringSync();

    test('completed location and budget suppress setup rows', () {
      expect(source, contains('showLocation: !hasPlanLocation'));
      expect(source, contains('showBudget: !hasPlanBudget'));
      expect(source, contains('location.hasAnyLocation'));
      expect(source, contains('_positiveMoney(summary?.budgetTotal)'));
      expect(source, contains('_positiveMoney(plan.estimatedBudget)'));
    });

    test(
      'missing optional address is not displayed as saved optional data',
      () {
        expect(source, isNot(contains("'أضف موقع الزفاف'")));
        expect(
          source,
          isNot(contains("_locationValue(location.governorate, 'اختياري')")),
        );
        expect(
          source,
          isNot(contains("_locationValue(location.cityOrDistrict, 'اختياري')")),
        );
        expect(
          source,
          contains("_locationValue(location.areaOrNeighborhood, 'لم يضف بعد')"),
        );
      },
    );
    test('generic unavailable copy is not used as metric data', () {
      expect(source, isNot(contains("?? 'غير متاح'")));
      expect(source, contains("?? 'لا توجد بيانات'"));
      expect(source, contains("?? 'لم تتم المزامنة'"));
    });
  });
}

String _findMobileRoot() {
  final cwd = Directory.current.path;
  if (cwd.endsWith('${Platform.pathSeparator}mobile') ||
      cwd.endsWith('/mobile')) {
    return '$cwd${Platform.pathSeparator}';
  }
  return '$cwd${Platform.pathSeparator}mobile${Platform.pathSeparator}';
}
