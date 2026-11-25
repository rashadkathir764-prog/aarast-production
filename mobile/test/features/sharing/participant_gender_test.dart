import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:flutter_test/flutter_test.dart';

// Q-67 (أ, D127): a participant's gender comes with the member and the
// invite, as the owner said it. A server from before sends none, and a
// participant never said stays of no known gender: the history then speaks
// of a partner bride in the feminine (the role says it) and of anyone else
// in the default form, as before.

Map<String, dynamic> _memberJson({Object? gender, String role = 'FAMILY'}) => {
  'id': 'member-1',
  'weddingPlanId': 'plan-1',
  'userId': 'user-1',
  'role': role,
  'gender': ?gender,
  'createdAt': '2026-07-16T00:00:00.000Z',
  'updatedAt': '2026-07-16T00:00:00.000Z',
};

void main() {
  test('a member reads its gender, and none from an older server', () {
    expect(
      SharedMember.fromJson(_memberJson(gender: 'FEMALE')).gender,
      ParticipantGender.female,
    );
    expect(
      SharedMember.fromJson(_memberJson(gender: 'MALE')).gender,
      ParticipantGender.male,
    );
    expect(SharedMember.fromJson(_memberJson()).gender, isNull);
    expect(SharedMember.fromJson(_memberJson(gender: 'OTHER')).gender, isNull);
  });

  test('the history speaks of a member as said, a partner bride by role', () {
    expect(
      SharedMember.fromJson(_memberJson(gender: 'FEMALE')).speaksFeminine,
      isTrue,
    );
    expect(SharedMember.fromJson(_memberJson()).speaksFeminine, isFalse);
    expect(
      SharedMember.fromJson(_memberJson(role: 'BRIDE')).speaksFeminine,
      isTrue,
    );
    expect(
      SharedMember.fromJson(
        _memberJson(role: 'BRIDE', gender: 'MALE'),
      ).speaksFeminine,
      isFalse,
    );
  });

  test('an invite reads its gender, and keeps it without its raw link', () {
    final invite = PlanInvite.fromJson({
      'id': 'invite-1',
      'weddingPlanId': 'plan-1',
      'token': 'raw',
      'role': 'FAMILY',
      'status': 'PENDING',
      'gender': 'FEMALE',
    });
    expect(invite.gender, ParticipantGender.female);
    expect(invite.withIdentityToken().gender, ParticipantGender.female);
    expect(
      PlanInvite.fromJson({
        'id': 'invite-2',
        'weddingPlanId': 'plan-1',
        'role': 'VIEWER',
      }).gender,
      isNull,
    );
  });
}
