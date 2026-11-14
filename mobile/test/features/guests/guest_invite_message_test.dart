import 'package:aarast_mobile/core/experience_v3/aarast_journey_profile.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/models/guest_invite_text.dart';
import 'package:aarast_mobile/features/guests/models/guest_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

// The preview on e04 / e08 is what the guest receives: the server's
// buildRsvpMessage and invitationPreview (backend/src/guests/
// guest-rsvp.service.ts), drawn before any link exists. These pin the
// phone's copy of those words to the server's order and wording.

Guest _guest(
  String id, {
  String invitationStatus = 'SENT',
  String attendanceStatus = 'PENDING',
  String? phone = '+967777000111',
  bool editable = true,
}) {
  final now = DateTime.utc(2026, 10, 15);
  return Guest(
    id: id,
    weddingPlanId: 'plan-1',
    name: id,
    phone: phone,
    side: 'GROOM',
    status: 'INVITED',
    attendanceStatus: attendanceStatus,
    invitationStatus: invitationStatus,
    seatsCount: 1,
    editable: editable,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final card = GuestInviteCard(
    title: 'عرس محمد',
    host: 'عبدالرحمن الحمدي',
    weddingDate: DateTime(2027, 2, 18),
    timeLabel: 'الساعة 20:30',
    place: 'قاعة سبأ الكبرى',
    freeText: 'يا مرحبا بالحاضرين',
    mapUrl: 'https://maps.app.goo.gl/abc',
    address: 'شارع تعز',
  );

  test('the invitation reads in the server\'s order, the link first', () {
    final lines = card.messageLines(
      guestName: 'ياسر',
      link: 'LINK',
      occasions: const [
        GuestInviteOccasion(
          label: 'المقيل',
          when: '17/2/2027 بعد العصر',
          place: 'بيت العريس',
        ),
        GuestInviteOccasion(label: 'الغداء'),
      ],
    );
    expect(lines, [
      'أهلًا ياسر 🌸',
      'يتشرف عبدالرحمن الحمدي بدعوتكم لحضور عرس محمد.',
      'يا مرحبا بالحاضرين',
      'نرجو تأكيد حضورك من الرابط:',
      'LINK',
      'الموعد: 18/2/2027 الساعة 20:30',
      'المكان: قاعة سبأ الكبرى',
      'والدعوة تشمل أيضًا:',
      '• المقيل: 17/2/2027 بعد العصر · بيت العريس',
      '• الغداء',
      // A map link wins over the address, as the server writes it.
      'الموقع على الخريطة: https://maps.app.goo.gl/abc',
    ]);
  });

  test('without a host or a map, the plain line and the address', () {
    const plain = GuestInviteCard(
      title: 'عرس سلمى',
      address: 'جوار جامع النور',
      profile: JourneyProfile.bride,
    );
    expect(plain.messageLines(guestName: 'أم علي', link: 'LINK'), [
      'أهلًا أم علي 🌸',
      'يسعدنا دعوتك لحضور عرس سلمى.',
      'نرجو تأكيد حضورك من الرابط:',
      'LINK',
      'العنوان: جوار جامع النور',
    ]);
    expect(
      const GuestInviteCard(
        title: 'عرس سلمى',
        host: 'أم سلمى',
        profile: JourneyProfile.bride,
      ).invitationLine,
      'تتشرف أم سلمى بدعوتكن لحضور عرس سلمى',
    );
  });

  test('the link preview is the invitation line, the day and the place', () {
    expect(card.linkTitle, 'يتشرف عبدالرحمن الحمدي بدعوتكم لحضور عرس محمد');
    expect(
      card.linkDescription,
      'الموعد: 18/2/2027 الساعة 20:30 · المكان: قاعة سبأ الكبرى. '
      'نرجو تأكيد حضورك من الرابط.',
    );
    expect(
      const GuestInviteCard(title: 'عرس محمد').linkDescription,
      'نرجو تأكيد حضورك من الرابط.',
    );
  });

  test('the reminder is the server\'s short text with the new link', () {
    expect(card.reminderLines(guestName: 'ياسر', link: 'LINK'), [
      'أهلًا ياسر',
      'نذكرك بعرس محمد يوم 18/2/2027.',
      'هذا رابطك الجديد للرد بضغطة:',
      'LINK',
    ]);
    expect(
      const GuestInviteCard(
        title: 'عرس محمد',
      ).reminderLines(guestName: 'ياسر', link: 'LINK')[1],
      'نذكرك بعرس محمد.',
    );
  });

  // «ذكّر الكل»: the server does not ask a guest who confirmed to answer
  // again (`buildRsvpMessage`, `confirmed`).
  test('the reminder to a guest who confirmed asks for no answer', () {
    expect(
      card.reminderLines(guestName: 'ياسر', link: 'LINK', confirmed: true),
      [
        'أهلًا ياسر',
        'نذكرك بعرس محمد يوم 18/2/2027.',
        'ننتظرك. ولو تغيّر شي، هذا رابطك:',
        'LINK',
      ],
    );
  });

  test('who a reminder goes to: not confirmed, or everyone invited', () {
    final pending = _guest('pending');
    final confirmed = _guest('confirmed', attendanceStatus: 'CONFIRMED');
    final declined = _guest('declined', attendanceStatus: 'DECLINED');
    final uninvited = _guest('uninvited', invitationStatus: 'NOT_SENT');
    final others = _guest('others', editable: false);
    final all = [pending, confirmed, declined, uninvited, others];

    List<String> ids(GuestReminderAudience audience) => [
      for (final guest in all)
        if (audience.includes(guest)) guest.id,
    ];
    expect(ids(GuestReminderAudience.notConfirmed), ['pending']);
    // Who apologised is not reminded, and who never got the invitation
    // would get a reminder of an invitation they never saw.
    expect(ids(GuestReminderAudience.everyone), ['pending', 'confirmed']);
  });

  test('a reminder round remembers who was passed, per audience', () {
    final round = GuestReminderRound(GuestReminderAudience.everyone)
      ..pass('a')
      ..pass('b');
    final guests = [_guest('a'), _guest('b'), _guest('c')];
    expect(round.left(guests).map((guest) => guest.id), ['c']);
    expect(round.passedCount, 2);
  });
}
