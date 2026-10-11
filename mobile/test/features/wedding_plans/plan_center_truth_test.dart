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

    test('management screen loads real plan and administrative summary data', () {
      // The plan management library spans part files (spec M6).
      final source = readLibrarySource(
        '${mobileRoot}lib/features/wedding_plans/screens/plan_management_screen.dart',
      );

      expect(
        source,
        matches(RegExp(r'loadWeddingPlan\(\s*widget\.weddingPlanId,?\s*\)')),
      );
      expect(source, contains('loadDashboard('));
      expect(source, contains('PlanManagementView('));
      expect(source, contains('summary?.participantCount'));
      expect(source, contains('summary?.permissions.canManagePlan'));
    });

    test('server and local edits preserve structured administrative fields', () {
      // The plan management library spans part files (spec M6).
      final source = readLibrarySource(
        '${mobileRoot}lib/features/wedding_plans/screens/plan_management_screen.dart',
      );

      // The server payload lives in PlanEditResult. Currency is fixed at plan
      // creation and rejected by UpdateWeddingPlanDto (F01), so only a local
      // plan applies it; plan_edit_result_test.dart pins the payload keys.
      final payloadSource = File(
        '${mobileRoot}lib/features/wedding_plans/models/plan_edit_result.dart',
      ).readAsStringSync();
      for (final field in [
        "'title':",
        "'weddingDate':",
        "'location':",
        "'priorities':",
      ]) {
        expect(payloadSource, contains(field));
      }
      expect(payloadSource, isNot(contains("'currency':")));
      expect(source, contains('currency: result.currency'));
      expect(source, contains('GuestOnboardingStorage'));
      expect(source, contains('saveDraft('));
      expect(source, contains('governorate'));
      expect(source, contains('areaOrNeighborhood'));
      expect(source, contains('detailedAddress'));
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
