import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'post-auth entry never treats the legacy SafeUser provider role as exclusive authority',
    () {
      final dashboard = File(
        'lib/features/home/screens/dashboard_entry_screen.dart',
      ).readAsStringSync();
      final login = File(
        'lib/features/auth/screens/login_screen.dart',
      ).readAsStringSync();
      final otp = File(
        'lib/features/auth/screens/otp_screen.dart',
      ).readAsStringSync();

      expect(dashboard, isNot(contains('isProviderAccount')));
      expect(dashboard, isNot(contains('ProviderPortalScreen')));
      expect(login, isNot(contains('isProviderAccount')));
      expect(otp, isNot(contains('isProviderAccount')));
      expect(
        login,
        contains(
          'context.go(_safeResumeLocation(context) ?? AppRouter.home);',
        ),
      );
      expect(
        otp,
        contains('context.go(widget.successLocation ?? AppRouter.home);'),
      );
    },
  );

  test(
    'provider application refreshes user then contexts before status navigation',
    () {
      for (final path in [
        'lib/features/marketplace/screens/provider_apply_screen.dart',
        'lib/features/auth/screens/otp_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        final refreshUser = source.indexOf('await auth.refreshCurrentUser()');
        final refreshContexts = source.indexOf(
          'await accountContexts.refresh(',
          refreshUser < 0 ? 0 : refreshUser,
        );
        final statusNavigation = source.indexOf(
          'context.go(AppRouter.providerApplyStatus)',
          refreshContexts < 0 ? 0 : refreshContexts,
        );

        expect(refreshUser, greaterThanOrEqualTo(0), reason: path);
        expect(refreshContexts, greaterThan(refreshUser), reason: path);
        expect(statusNavigation, greaterThan(refreshContexts), reason: path);
        expect(
          source,
          contains(
            'activeWeddingPlanId: auth.user?.activeWeddingPlanId',
          ),
          reason: '$path must preserve the authenticated wedding selection',
        );
      }
    },
  );
}
