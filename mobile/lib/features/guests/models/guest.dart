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
  });

  factory Guest.fromJson(Map<String, dynamic> json) {
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
      createdAt: _dateTimeOrNull(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeOrNull(json['updatedAt']) ?? DateTime.now(),
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

  bool get isConfirmed =>
      attendanceStatus == 'CONFIRMED' || status == 'CONFIRMED';

  bool get isDeclined => attendanceStatus == 'DECLINED' || status == 'DECLINED';

  bool get isPending => !isConfirmed && !isDeclined;

  bool get hasPhone => phone?.trim().isNotEmpty == true;

  bool get hasMissingData => name.trim().isEmpty || !hasPhone;

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
  });

  factory GuestGroup.fromJson(Map<String, dynamic> json) {
    return GuestGroup(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      name: json['name']?.toString() ?? '',
      notes: json['notes']?.toString(),
      sortOrder: int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0,
    );
  }

  final String id;
  final String weddingPlanId;
  final String name;
  final String? notes;
  final int sortOrder;
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
    return GuestSummary(
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
    final bySide = {'groom': 0, 'bride': 0, 'unknown': 0};
    final byGroup = <String, int>{};
    final groupNames = {for (final group in groups) group.id: group.name};

    for (final guest in guests) {
      if (guest.isConfirmed) {
        confirmed++;
      } else if (guest.isDeclined) {
        declined++;
      } else {
        pending++;
      }
      if (!guest.hasPhone) missingPhone++;
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
  final int missingPhoneCount;
  final int missingNameCount;
  final int incompleteGuestsCount;
  final int expectedSeatsCount;
  final int companionsExpectedCount;
  final Map<String, int> bySideForSuper;
  final Map<String, int> byGroup;
  final int groupsCount;

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
  Uri get whatsAppUri {
    final digits = phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    return Uri.https('wa.me', digits.isEmpty ? '/' : '/$digits', {
      'text': message,
    });
  }
}
