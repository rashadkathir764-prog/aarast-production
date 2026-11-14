import 'guest.dart';

/// e08: who a reminder goes to. The server keeps no reminder state: it
/// makes a new link and the reminder's text for any guest it is asked for,
/// so who is in each choice is decided here, from the guest's own row.
enum GuestReminderAudience {
  /// Invited and not answered yet.
  notConfirmed,

  /// Everyone the invitation reached, except who apologised: a reminder of
  /// the day to who is coming as well.
  everyone;

  bool includes(Guest guest) => switch (this) {
    notConfirmed => guest.canBeReminded,
    everyone =>
      guest.editable &&
          guest.invitationStatus != 'NOT_SENT' &&
          !guest.isDeclined,
  };
}

/// One reminder round on this phone: the guests already passed in it (sent
/// or skipped). Leaving the screen and coming back continues from here; it
/// lives as long as the session's guests provider, never on the server.
class GuestReminderRound {
  GuestReminderRound(this.audience);

  final GuestReminderAudience audience;
  final Set<String> _passed = {};

  int get passedCount => _passed.length;

  void pass(String guestId) => _passed.add(guestId);

  /// [guests] who are still to be reminded in this round, in their order.
  List<Guest> left(List<Guest> guests) => [
    for (final guest in guests)
      if (!_passed.contains(guest.id)) guest,
  ];
}
