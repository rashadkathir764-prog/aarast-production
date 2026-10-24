import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/phone/phone_number_utils.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/participant_access.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/edit_shared_member_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('a Yemeni mobile reads «777 123 456»; others stay as shown', () {
    expect(participantPhone('+967777123456'), '777 123 456');
    expect(participantPhone('777123456'), '777 123 456');
    expect(participantPhone(null), isNull);
    expect(participantPhone('+966501234567'), '+966501234567');
  });

  testWidgets('a phone-only member keeps the number in order at 320px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.reset);

    final provider = SharingProvider(_Api())..selectMember(_phoneOnlyMember());
    await tester.pumpWidget(
      ChangeNotifierProvider<SharingProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: EditSharedMemberScreen(sharedMemberId: 'member-phone'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(PhoneNumberUtils.isolateLtr('777 123 456')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('phone-only invite exposes an isolated RTL-safe display name', () {
    final invite = _phoneOnlyInvite();

    expect(invite.displayNamePhone, '+967777123456');
    expect(
      invite.directionalDisplayName,
      PhoneNumberUtils.isolateLtr('+967 777 123 456'),
    );
  });
}

class _Api extends SharingApi {
  _Api() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async => PlanAccessPermissions.owner(weddingPlanId: weddingPlanId);

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async => [
    _phoneOnlyMember(),
  ];

  @override
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async =>
      const [];
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
