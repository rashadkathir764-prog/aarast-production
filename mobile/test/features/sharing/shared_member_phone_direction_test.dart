import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/widgets/shared_member_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone-only member stays LTR at 320px and 1.3 text scale', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: Scaffold(
              body: SharedMemberCard(member: _phoneOnlyMember(), onTap: null),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final phoneText = tester.widget<Text>(find.text('+967 777 123 456'));
    expect(phoneText.textDirection, TextDirection.ltr);
    expect(tester.takeException(), isNull);
  });

  test('phone-only invite exposes an isolated RTL-safe display name', () {
    final invite = _phoneOnlyInvite();

    expect(invite.displayNamePhone, '+967777123456');
    expect(invite.directionalDisplayName, '\u2066+967 777 123 456\u2069');
  });
}

SharedMember _phoneOnlyMember() {
  return SharedMember(
    id: 'member-phone',
    weddingPlanId: 'plan-1',
    userId: 'user-phone',
    user: const SharedMemberUser(
      id: 'user-phone',
      name: '',
      phone: '+967777123456',
    ),
    role: 'VIEWER',
    canViewMoney: false,
    canManageTasks: false,
    canManageMoney: false,
    createdAt: DateTime(2026, 7, 16),
    updatedAt: DateTime(2026, 7, 16),
  );
}

PlanInvite _phoneOnlyInvite() {
  return PlanInvite(
    id: 'invite-phone',
    weddingPlanId: 'plan-1',
    token: 'token',
    role: 'HELPER',
    status: 'PENDING',
    expiresAt: DateTime(2026, 7, 30),
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: true,
    canManageGuests: true,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
    phone: '+967777123456',
  );
}
