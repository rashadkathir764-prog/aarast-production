import 'guest_invite_text.dart';

/// D99 (RA-BE-62): how many guests one plan holds, the server's
/// PLAN_GUESTS_MAX. The plan's list is read whole, so the phone stops an add
/// past it itself instead of queueing one the server refuses.
const planGuestsMax = 5000;

/// Why an add past [planGuestsMax] is refused, in the server's own words
/// (PLAN_GUESTS_LIMIT); [count] is how many guests the plan has now.
String planGuestsFullMessage(int count) =>
    'الخطة تشيل $planGuestsMax اسم بالكثير، وفيها الحين $count.';

/// D83: the guest's reply to one of the plan's events beyond the wedding
/// (the lunch, the aqd...). Their reply to the wedding itself is the guest's
/// own `attendanceStatus`.
class GuestEventReply {
  const GuestEventReply({
    required this.planEventId,
    this.attendanceStatus = 'PENDING',
    this.companionsCount = 0,
    this.respondedAt,
  });

  factory GuestEventReply.fromJson(Map<String, dynamic> json) {
    return GuestEventReply(
      planEventId: json['planEventId']?.toString() ?? '',
      attendanceStatus: json['attendanceStatus']?.toString() ?? 'PENDING',
      companionsCount:
          int.tryParse(json['companionsCount']?.toString() ?? '') ?? 0,
      respondedAt: Guest._dateTimeOrNull(json['respondedAt']),
    );
  }

  final String planEventId;
  final String attendanceStatus;
  final int companionsCount;
  final DateTime? respondedAt;

  bool get isConfirmed => attendanceStatus == 'CONFIRMED';
  bool get isDeclined => attendanceStatus == 'DECLINED';
  bool get isPending => !isConfirmed && !isDeclined;
}

class Guest {
  const Guest({
    required this.id,
    required this.weddingPlanId,
    required this.name,
    required this.side,
    required this.status,
    required this.seatsCount,
    required this.createdAt,
    required this.updatedAt,
    this.companionsCount = 0,
    this.invitationStatus = 'NOT_SENT',
    this.attendanceStatus = 'PENDING',
    this.groupId,
    this.phone,
    this.notes,
    this.editable = true,
    this.events = const [],
  });

  factory Guest.fromJson(Map<String, dynamic> json) {
    final events = json['events'];
    return Guest(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      groupId: json['groupId']?.toString(),
      name: json['name'].toString(),
      phone: json['phone']?.toString(),
      side: json['side']?.toString() ?? 'OTHER',
      status: json['status']?.toString() ?? 'INVITED',
      seatsCount: int.tryParse(json['seatsCount']?.toString() ?? '') ?? 1,
      companionsCount:
          int.tryParse(json['companionsCount']?.toString() ?? '') ?? 0,
      invitationStatus: json['invitationStatus']?.toString() ?? 'NOT_SENT',
      attendanceStatus:
          json['attendanceStatus']?.toString() ??
          _attendanceStatusFromStatus(json['status']?.toString()),
      notes: json['notes']?.toString(),
      // An older server sends no flag and only the reader's own guests.
      editable: json['editable'] != false,
      createdAt: _dateTimeOrNull(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeOrNull(json['updatedAt']) ?? DateTime.now(),
      events: [
        if (events is List)
          for (final item in events)
            if (item is Map)
              GuestEventReply.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  final String id;
  final String weddingPlanId;
  final String? groupId;
  final String name;
  final String? phone;
  final String side;
  final String status;
  final int seatsCount;
  final int companionsCount;
  final String invitationStatus;
  final String attendanceStatus;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// D80: the reader may change this guest and reads its number: the owner
  /// for every guest, a helper for the guests they added. Every other guest
  /// is read by name and reply only.
  final bool editable;

  /// D83: the plan's events beyond the wedding this guest is invited to.
  final List<GuestEventReply> events;

  List<String> get eventIds => [for (final event in events) event.planEventId];

  bool get isConfirmed =>
      attendanceStatus == 'CONFIRMED' || status == 'CONFIRMED';

  bool get isDeclined => attendanceStatus == 'DECLINED' || status == 'DECLINED';

  bool get isPending => !isConfirmed && !isDeclined;

  /// Invited and not answered: who is waited on for a reminder (e08). Only a
  /// guest the reader keeps: another's guest has no number or link to send.
  /// The reminder screen says who of them has no number; a count of who a
  /// reminder reaches is [canBeRemindedOnWhatsApp].
  bool get canBeReminded =>
      editable && isPending && invitationStatus != 'NOT_SENT';

  /// Waited on and reachable: the reminder goes to a number (RA-MO-61: «ذكّر
  /// الـ N» counted the guests without one; RA-MO-66: the rule belongs to the
  /// count, not to who is waited on, or the screen said nobody was waiting).
  bool get canBeRemindedOnWhatsApp => canBeReminded && hasPhone;

  /// No invitation has gone out to this guest yet (e04), from this reader.
  bool get awaitsInvitation =>
      editable && invitationStatus == 'NOT_SENT' && !isDeclined;

  bool get hasPhone => phone?.trim().isNotEmpty == true;

  /// The number is missing, not kept by the owner (D80).
  bool get missesPhone => editable && !hasPhone;

  bool get hasMissingData => name.trim().isEmpty || missesPhone;

  /// This guest after its group is deleted: the server keeps the guest and
  /// only clears the group (`onDelete: SetNull`).
  Guest withoutGroup() => Guest(
    id: id,
    weddingPlanId: weddingPlanId,
    name: name,
    side: side,
    status: status,
    seatsCount: seatsCount,
    createdAt: createdAt,
    updatedAt: updatedAt,
    companionsCount: companionsCount,
    invitationStatus: invitationStatus,
    attendanceStatus: attendanceStatus,
    phone: phone,
    notes: notes,
    editable: editable,
    events: events,
  );

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String _attendanceStatusFromStatus(String? status) {
    return switch (status) {
      'CONFIRMED' => 'CONFIRMED',
      'DECLINED' => 'DECLINED',
      _ => 'PENDING',
    };
  }
}

class GuestGroup {
  const GuestGroup({
    required this.id,
    required this.weddingPlanId,
    required this.name,
    this.notes,
    this.sortOrder = 0,
    this.editable = true,
  });

  factory GuestGroup.fromJson(Map<String, dynamic> json) {
    return GuestGroup(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      name: json['name']?.toString() ?? '',
      notes: json['notes']?.toString(),
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
      editable: json['editable'] != false,
    );
  }

  final String id;
  final String weddingPlanId;
  final String name;
  final String? notes;
  final int sortOrder;

  /// D80: the reader may rename, remove and add guests to this group.
  final bool editable;
}

/// D83: one event's figures in the guests summary (the server's).
class GuestEventCounters {
  const GuestEventCounters({
    required this.planEventId,
    required this.label,
    required this.invited,
    required this.confirmed,
    required this.declined,
    required this.pending,
    required this.companions,
  });

  factory GuestEventCounters.fromJson(Map<String, dynamic> json) {
    return GuestEventCounters(
      planEventId: json['planEventId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      invited: GuestSummary._intOrZero(json['invited']),
      confirmed: GuestSummary._intOrZero(json['confirmed']),
      declined: GuestSummary._intOrZero(json['declined']),
      pending: GuestSummary._intOrZero(json['pending']),
      companions: GuestSummary._intOrZero(json['companions']),
    );
  }

  final String planEventId;
  final String label;
  final int invited;
  final int confirmed;
  final int declined;
  final int pending;
  final int companions;
}

/// D83: the plan's one invitation card, as the account keeps it. The
/// names, the date, the time and the venue are the plan's, not the card's.
class InvitationCard {
  const InvitationCard({
    this.hostLine,
    this.freeText,
    this.photoUrl,
    this.mapUrl,
    this.address,
    this.updatedAt,
  });

  factory InvitationCard.fromJson(Map<String, dynamic> json) {
    String? text(Object? value) {
      final trimmed = value?.toString().trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    }

    return InvitationCard(
      hostLine: text(json['hostLine']),
      freeText: text(json['freeText']),
      photoUrl: text(json['photoUrl']),
      mapUrl: text(json['mapUrl']),
      address: text(json['address']),
      updatedAt: Guest._dateTimeOrNull(json['updatedAt']),
    );
  }

  final String? hostLine;
  final String? freeText;
  final String? photoUrl;
  final String? mapUrl;
  final String? address;
  final DateTime? updatedAt;

  bool get isEmpty =>
      hostLine == null &&
      freeText == null &&
      photoUrl == null &&
      mapUrl == null &&
      address == null;
}

class GuestSummary {
  const GuestSummary({
    required this.weddingPlanId,
    required this.totalGuests,
    required this.confirmed,
    required this.pending,
    required this.declined,
    required this.missingPhoneCount,
    required this.missingNameCount,
    required this.incompleteGuestsCount,
    required this.expectedSeatsCount,
    required this.companionsExpectedCount,
    required this.bySideForSuper,
    required this.byGroup,
    required this.groupsCount,
    this.byEvent = const [],
    this.confirmedSeatsCount = 0,
  });

  factory GuestSummary.empty(String weddingPlanId) {
    return GuestSummary(
      weddingPlanId: weddingPlanId,
      totalGuests: 0,
      confirmed: 0,
      pending: 0,
      declined: 0,
      missingPhoneCount: 0,
      missingNameCount: 0,
      incompleteGuestsCount: 0,
      expectedSeatsCount: 0,
      companionsExpectedCount: 0,
      bySideForSuper: const {'groom': 0, 'bride': 0, 'unknown': 0},
      byGroup: const {},
      groupsCount: 0,
    );
  }

  factory GuestSummary.fromJson(Map<String, dynamic> json) {
    final weddingPlanId = json['weddingPlanId']?.toString() ?? '';
    final bySide = _mapOfInt(json['bySideForSuper']);
    final byGroup = _mapOfInt(json['byGroup']);
    final byEvent = json['byEvent'];
    return GuestSummary(
      byEvent: [
        if (byEvent is List)
          for (final item in byEvent)
            if (item is Map)
              GuestEventCounters.fromJson(Map<String, dynamic>.from(item)),
      ],
      weddingPlanId: weddingPlanId,
      totalGuests:
          _intOrNull(json['totalGuests']) ?? _intOrZero(json['guestCount']),
      confirmed:
          _intOrNull(json['confirmed']) ?? _intOrZero(json['confirmedGuests']),
      pending:
          _intOrNull(json['pending']) ??
          _intOrNull(json['waiting']) ??
          _intOrZero(json['pendingGuests']),
      declined:
          _intOrNull(json['declined']) ??
          _intOrNull(json['notAttending']) ??
          _intOrZero(json['declinedGuests']),
      missingPhoneCount: _intOrZero(json['missingPhoneCount']),
      missingNameCount: _intOrZero(json['missingNameCount']),
      incompleteGuestsCount: _intOrZero(json['incompleteGuestsCount']),
      expectedSeatsCount:
          _intOrNull(json['expectedSeatsCount']) ??
          _intOrZero(json['seatsTotal']),
      companionsExpectedCount:
          _intOrNull(json['companionsExpectedCount']) ??
          _intOrZero(json['companionsTotal']),
      bySideForSuper: {
        'groom': bySide['groom'] ?? 0,
        'bride': bySide['bride'] ?? 0,
        'unknown': bySide['unknown'] ?? 0,
      },
      byGroup: byGroup,
      groupsCount: _intOrZero(json['groupsCount']),
    );
  }

  factory GuestSummary.fromGuests({
    required String weddingPlanId,
    required List<Guest> guests,
    List<GuestGroup> groups = const [],
  }) {
    var confirmed = 0;
    var pending = 0;
    var declined = 0;
    var missingPhone = 0;
    var missingName = 0;
    var expectedSeats = 0;
    var companions = 0;
    var confirmedSeats = 0;
    final bySide = {'groom': 0, 'bride': 0, 'unknown': 0};
    final byGroup = <String, int>{};
    final groupNames = {for (final group in groups) group.id: group.name};

    for (final guest in guests) {
      if (guest.isConfirmed) {
        confirmed++;
        // RA-MO-59: a confirmed guest and who comes with them: the form's
        // seats, or the reply's companions (a reply by link writes only
        // those), whichever says more.
        final withCompanions = 1 + guest.companionsCount;
        confirmedSeats += guest.seatsCount > withCompanions
            ? guest.seatsCount
            : withCompanions;
      } else if (guest.isDeclined) {
        declined++;
      } else {
        pending++;
      }
      if (guest.missesPhone) missingPhone++;
      if (guest.name.trim().isEmpty) missingName++;
      expectedSeats += guest.seatsCount;
      companions += guest.companionsCount;

      final sideKey = switch (guest.side) {
        'GROOM' => 'groom',
        'BRIDE' => 'bride',
        _ => 'unknown',
      };
      bySide[sideKey] = (bySide[sideKey] ?? 0) + 1;

      final groupName = guest.groupId == null
          ? 'ungrouped'
          : groupNames[guest.groupId] ?? 'grouped';
      byGroup[groupName] = (byGroup[groupName] ?? 0) + 1;
    }

    return GuestSummary(
      weddingPlanId: weddingPlanId,
      totalGuests: guests.length,
      confirmed: confirmed,
      pending: pending,
      declined: declined,
      missingPhoneCount: missingPhone,
      missingNameCount: missingName,
      incompleteGuestsCount: guests
          .where((guest) => guest.hasMissingData)
          .length,
      expectedSeatsCount: expectedSeats,
      companionsExpectedCount: companions,
      confirmedSeatsCount: confirmedSeats,
      bySideForSuper: bySide,
      byGroup: byGroup,
      groupsCount: groups.length,
    );
  }

  final String weddingPlanId;
  final int totalGuests;
  final int confirmed;
  final int pending;
  final int declined;

  /// RA-MO-59: the seats the confirmed guests need, their companions
  /// counted (the hall's and the caterer's number); counted on the phone.
  final int confirmedSeatsCount;
  final int missingPhoneCount;
  final int missingNameCount;
  final int incompleteGuestsCount;
  final int expectedSeatsCount;
  final int companionsExpectedCount;
  final Map<String, int> bySideForSuper;
  final Map<String, int> byGroup;
  final int groupsCount;

  /// D83: per event beyond the wedding, in the plan's order; only events
  /// with invited guests. Empty for a plan kept on the phone.
  final List<GuestEventCounters> byEvent;

  double get completionRatio {
    if (totalGuests <= 0) return 0;
    final complete = totalGuests - incompleteGuestsCount;
    return complete.clamp(0, totalGuests) / totalGuests;
  }

  int get completionPercent => (completionRatio * 100).round();

  static int _intOrZero(Object? value) => _intOrNull(value) ?? 0;

  static int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static Map<String, int> _mapOfInt(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        entry.key.toString(): _intOrZero(entry.value),
    };
  }
}

/// A guest's personal RSVP link and the WhatsApp text that carries it (4.7).
class GuestInvitationLink {
  const GuestInvitationLink({
    required this.url,
    required this.message,
    this.phone,
  });

  final String url;
  final String message;

  /// The guest's number in E.164, when the plan has it.
  final String? phone;

  /// WhatsApp with the message ready: to the guest's chat when the number is
  /// known, otherwise WhatsApp's own picker.
  Uri get whatsAppUri => guestWhatsAppUri(phone, message);
}
