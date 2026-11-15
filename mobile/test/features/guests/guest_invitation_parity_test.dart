import 'dart:convert';
import 'dart:io';

import 'package:aarast_mobile/features/guests/models/guest_invitations.dart';
import 'package:flutter_test/flutter_test.dart';

// D116: the phone counts the guests tab and draws the card's preview without
// the server, with the server's rules and words. The server's test writes
// what it answers for fixed cases (backend/test/
// guest-invitation-fixtures.test.ts); the phone must answer the same.

void main() {
  final fixtures =
      jsonDecode(
            File(
              'test/fixtures/guest_invitation_fixtures.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  group('where a guest stands, what they are due, what a send names', () {
    for (final raw in fixtures['standings'] as List) {
      final entry = raw as Map<String, dynamic>;
      test(entry['name'] as String, () {
        final input = entry['input'] as Map<String, dynamic>;
        final answer = entry['answer'] as Map<String, dynamic>;
        final sends = [
          for (final send in input['sends'] as List)
            SentInvitation(
              kind: InvitationSendKind.fromWire(send['kind'])!,
              sentAt: DateTime.parse(send['sentAt'] as String),
              events: [
                for (final event in send['events'] as List)
                  (
                    planEventId: event['planEventId'] as String,
                    version: event['version'] as int,
                  ),
              ],
            ),
        ];
        final told = toldOccasions(sends);
        expect([
          for (final MapEntry(:key, :value) in told.entries)
            {
              'planEventId': key,
              'version': value.version,
              'at': value.at.toUtc().toIso8601String(),
              'remindedAt': value.remindedAt?.toUtc().toIso8601String(),
            },
        ], answer['told']);
        final standings = [
          for (final occasion in input['occasions'] as List)
            () {
              final id = occasion['planEventId'] as String;
              final invite = (input['invites'] as List).firstWhere(
                (candidate) => candidate['planEventId'] == id,
              );
              return (
                planEventId: id,
                standing: occasionStanding(
                  InviteAnswer(
                    planEventId: id,
                    attendanceStatus: invite['attendanceStatus'] as String,
                    companionsCount: invite['companionsCount'] as int,
                    answeredVersion: invite['answeredVersion'] as int?,
                  ),
                  occasion['version'] as int,
                  told[id],
                ),
                companionsCount: invite['companionsCount'] as int,
              );
            }(),
        ];
        expect([
          for (final standing in standings)
            {
              'planEventId': standing.planEventId,
              'standing': standing.standing.wire,
            },
        ], answer['standings']);
        expect({
          for (final standing in standings)
            standing.planEventId: occasionCounts([
              (
                standing: standing.standing,
                companionsCount: standing.companionsCount,
              ),
            ]).toJson(),
        }, answer['counts']);
        final scopeIds = (input['scope'] as List?)?.cast<String>();
        final scope = [
          for (final standing in standings)
            if (scopeIds == null || scopeIds.contains(standing.planEventId))
              (planEventId: standing.planEventId, standing: standing.standing),
        ];
        expect(dueSend(scope, everTold: told.isNotEmpty)?.wire, answer['due']);
        expect({
          for (final kind in InvitationSendKind.values)
            kind.wire: occasionsToName(kind, scope),
        }, answer['names']);
      });
    }
  });

  group('the WhatsApp text', () {
    for (final raw in fixtures['messages'] as List) {
      final entry = raw as Map<String, dynamic>;
      test(entry['name'] as String, () {
        final input = entry['input'] as Map<String, dynamic>;
        final card = input['card'] as Map<String, dynamic>?;
        final text = invitationMessage(
          guestName: input['guestName'] as String,
          planTitle: input['planTitle'] as String,
          url: input['url'] as String,
          kind:
              InvitationSendKind.fromWire(input['kind']) ??
              InvitationSendKind.invitation,
          bride: input['persona'] == 'BRIDE',
          hostLine: card?['hostLine'] as String?,
          freeText: card?['freeText'] as String?,
          confirmed: input['confirmed'] == true,
          occasions: [
            for (final occasion in input['occasions'] as List)
              InvitationOccasionText(
                label: occasion['label'] as String,
                isWedding: occasion['isWedding'] as bool,
                date: occasion['date'] == null
                    ? null
                    : DateTime.parse(occasion['date'] as String),
                timeSlot: occasion['timeSlot'] as String?,
                exactTime: occasion['exactTime'] as String?,
                placeLabel: occasion['placeLabel'] as String?,
                address: occasion['address'] as String?,
                mapUrl: occasion['mapUrl'] as String?,
              ),
          ],
        );
        expect(text, entry['text']);
      });
    }
  });
}
