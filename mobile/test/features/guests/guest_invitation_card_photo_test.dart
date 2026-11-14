import 'package:aarast_mobile/features/guests/data/guests_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:flutter_test/flutter_test.dart';

/// 6a: the bucket keeps the card photo private. The server gives the plan's
/// members a short signed read of it, and that is what the phone draws.
void main() {
  const stored = 'https://media.example/guest-invitation-card/u/a.jpg';
  const signed =
      'https://signed.example/guest-invitation-card/u/a.jpg?X-Amz-Expires=120';

  test(
    'the card draws the signed read of its photo, not the stored address',
    () {
      final card = InvitationCard.fromJson({
        'weddingPlanId': 'plan-1',
        'photoUrl': stored,
        'photoReadUrl': signed,
      });
      expect(card.photoUrl, signed);
      expect(card.isEmpty, isFalse);
      // A photo picked on this phone and still queued has no read yet: its
      // own address is all there is.
      expect(InvitationCard.fromJson({'photoUrl': stored}).photoUrl, stored);
      expect(InvitationCard.fromJson({'photoReadUrl': null}).photoUrl, isNull);
    },
  );

  test(
    'a photo changed on the phone drops the old photo\'s read; other changes keep it',
    () {
      final now = DateTime.utc(2026, 11, 14, 9);
      final cached = <String, dynamic>{
        'weddingPlanId': 'plan-1',
        'hostLine': 'أبو أحمد',
        'photoUrl': stored,
        'photoReadUrl': signed,
      };

      final host = InvitationCard.fromJson(
        localInvitationCard(cached, {'hostLine': 'أبو سالم'}, now),
      );
      expect(host.hostLine, 'أبو سالم');
      expect(host.photoUrl, signed, reason: 'the same photo, still readable');

      const picked = 'https://media.example/guest-invitation-card/u/b.jpg';
      final photo = InvitationCard.fromJson(
        localInvitationCard(cached, {'photoUrl': picked}, now),
      );
      expect(
        photo.photoUrl,
        picked,
        reason: 'never the old photo for the new one',
      );

      final cleared = InvitationCard.fromJson(
        localInvitationCard(cached, {'photoUrl': null}, now),
      );
      expect(cleared.photoUrl, isNull);
      expect(cleared.updatedAt, now);
    },
  );
}
