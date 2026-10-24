import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../support/library_source.dart';

void main() {
  group('Plan management truth contract', () {
    final mobileRoot = _findMobileRoot();

    test('legacy plan center path exports the focused management screen', () {
      final source = File(
        '${mobileRoot}lib/features/wedding_plans/screens/plan_center_screen.dart',
      ).readAsStringSync();

      expect(source, contains("export 'plan_management_screen.dart';"));
      expect(
        source.split('\n').where((line) => line.trim().isNotEmpty),
        hasLength(1),
      );
    });

    test('the owner sees w10 with the plan and its budget (D27)', () {
      // The plan management library spans part files (spec M6).
      final source = readLibrarySource(
        '${mobileRoot}lib/features/wedding_plans/screens/plan_management_screen.dart',
      );

      expect(
        source,
        matches(RegExp(r'loadWeddingPlan\(\s*widget\.weddingPlanId,?\s*\)')),
      );
      expect(source, contains('loadDashboard('));
      expect(source, contains('PlanDetailsView('));
      expect(source, contains('summary?.permissions.canManagePlan'));
      expect(source, contains('setTotalBudget('));
      expect(source, contains('showPostponeSheet('));
    });

    test('w10 saves only what changed, and a day as a plan day', () {
      final source = readLibrarySource(
        '${mobileRoot}lib/features/wedding_plans/screens/plan_management_screen.dart',
      );

      // The place and the currency stay as the plan was made (D27).
      expect(source, contains("'weddingDate': planDayToJson(firstDay)"));
      expect(source, isNot(contains("'currency':")));
      expect(source, isNot(contains("'location':")));
      // A plan kept on this phone saves to its draft.
      expect(source, contains('GuestOnboardingStorage'));
      expect(source, contains('saveDraft('));
    });

    test(
      'danger area uses archive only and never invents unsupported actions',
      () {
        // The plan management library spans part files (spec M6).
        final source = readLibrarySource(
          '${mobileRoot}lib/features/wedding_plans/screens/plan_management_screen.dart',
        );

        expect(source, contains('archiveWeddingPlan('));
        expect(source, isNot(contains('deleteWeddingPlan')));
        expect(source, isNot(contains('copyWeddingPlan')));
        expect(source, isNot(contains('exportWeddingPlan')));
      },
    );
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
