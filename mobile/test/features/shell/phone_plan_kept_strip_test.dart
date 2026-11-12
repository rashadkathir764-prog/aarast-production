import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/shell/widgets/phone_plan_kept_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D112 (Q-13), the owner's word: the other side's plan kept on a phone is a
// quiet strip, not a sheet at every open (RA-MO-107).

void main() {
  Future<({GuestOnboardingStorage storage, AuthController auth})> pump(
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = GuestOnboardingStorage(preferences);
    final authStorage = AuthStorage(preferences);
    final auth = AuthController(
      _SignedIn(
        ApiClient(tokenProvider: authStorage.readAccessToken),
        authStorage,
      ),
    );
    await auth.restoreSession();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GuestOnboardingStorage>.value(value: storage),
          ChangeNotifierProvider<AuthController>.value(value: auth),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: PhonePlanKeptStrip()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (storage: storage, auth: auth);
  }

  testWidgets('nothing was left on the phone: no strip', (tester) async {
    await pump(tester);

    expect(find.byKey(const ValueKey('phone-plan-kept-strip')), findsNothing);
  });

  testWidgets('says whose plan is on the phone, and «غيّر» asks again', (
    tester,
  ) async {
    final harness = await pump(tester);
    await harness.storage.keepForOwner(
      accountUserId: 'user-a',
      guestPlanId: 'local-1',
      ownerPersona: GuestPersona.bride,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('phone-plan-kept-strip')), findsOneWidget);
    expect(
      find.text('على هذا الجوال خطة العروسة. تحفظها هي برقمها.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('phone-plan-kept-change')));
    await tester.pumpAndSettle();

    expect(harness.storage.keptForOwnerBy('user-a'), isNull);
    expect(find.byKey(const ValueKey('phone-plan-kept-strip')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('another account on the phone does not read it', (tester) async {
    final harness = await pump(tester);
    await harness.storage.keepForOwner(
      accountUserId: 'someone-else',
      guestPlanId: 'local-1',
      ownerPersona: GuestPersona.groom,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('phone-plan-kept-strip')), findsNothing);
  });
}

class _SignedIn extends AuthRepository {
  _SignedIn(super.apiClient, super.authStorage);

  static const _user = SafeUser(
    id: 'user-a',
    name: 'محمد',
    role: 'USER',
    status: 'ACTIVE',
  );

  @override
  SafeUser? readCachedUser() => _user;

  @override
  Future<String?> readAccessToken() async => 'token';

  @override
  Future<SafeUser> me() async => _user;
}
