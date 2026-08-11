part of 'guest_list_screen.dart';

enum _GuestFilter {
  all,
  confirmed,
  pending,
  declined,
  incomplete,
  groom,
  bride,
}

class _FilterItem {
  const _FilterItem(this.filter, this.label);

  final _GuestFilter filter;
  final String label;
}

const _filterItems = [
  _FilterItem(_GuestFilter.all, 'الكل'),
  _FilterItem(_GuestFilter.confirmed, 'مؤكد'),
  _FilterItem(_GuestFilter.pending, 'بانتظار الرد'),
  _FilterItem(_GuestFilter.declined, 'لن يحضر'),
  _FilterItem(_GuestFilter.incomplete, 'ناقص بيانات'),
  _FilterItem(_GuestFilter.groom, 'طرف العريس'),
  _FilterItem(_GuestFilter.bride, 'طرف العروسة'),
];

List<Guest> _filteredGuests(List<Guest> guests, _GuestFilter filter) {
  return switch (filter) {
    _GuestFilter.all => guests,
    _GuestFilter.confirmed =>
      guests.where((guest) => guest.isConfirmed).toList(),
    _GuestFilter.pending => guests.where((guest) => guest.isPending).toList(),
    _GuestFilter.declined => guests.where((guest) => guest.isDeclined).toList(),
    _GuestFilter.incomplete =>
      guests.where((guest) => guest.hasMissingData).toList(),
    _GuestFilter.groom =>
      guests.where((guest) => guest.side == 'GROOM').toList(),
    _GuestFilter.bride =>
      guests.where((guest) => guest.side == 'BRIDE').toList(),
  };
}

List<_GuestIssue> _importantIssues(
  GuestSummary summary,
  Set<String> duplicates,
) {
  if (summary.incompleteGuestsCount > 0) {
    return [
      _GuestIssue(
        label: _incompleteGuestsLabel(summary.incompleteGuestsCount),
        detail: _incompleteGuestsDetail(summary),
        filter: _GuestFilter.incomplete,
        icon: LucideIcons.alertTriangle,
        tone: AarastV3AttentionTone.warning,
      ),
    ];
  }
  if (duplicates.isNotEmpty) {
    return [
      _GuestIssue(
        label: duplicates.length == 1
            ? 'تكرار محتمل يحتاج مراجعة'
            : '${duplicates.length} تكرارات محتملة تحتاج مراجعة',
        detail: 'راجع أرقام الجوال قبل متابعة الدعوات',
        filter: _GuestFilter.all,
        icon: LucideIcons.copy,
        tone: AarastV3AttentionTone.danger,
      ),
    ];
  }
  if (summary.pending > 0) {
    return [
      _GuestIssue(
        label: _pendingGuestsLabel(summary.pending),
        detail: 'راجع الدعوات التي لم يصل ردها بعد',
        filter: _GuestFilter.pending,
        icon: LucideIcons.hourglass,
        tone: AarastV3AttentionTone.information,
      ),
    ];
  }
  return const [];
}

String _incompleteGuestsLabel(int count) {
  return switch (count) {
    1 => 'ضيف واحد يحتاج إكمال بياناته',
    2 => 'ضيفان يحتاجان إكمال بياناتهما',
    >= 3 && <= 10 => '$count ضيوف يحتاجون إكمال بياناتهم',
    _ => '$count ضيفًا يحتاجون إكمال بياناتهم',
  };
}

String _incompleteGuestsDetail(GuestSummary summary) {
  if (summary.missingPhoneCount == 1 && summary.incompleteGuestsCount == 1) {
    return 'رقم الجوال غير مضاف بعد';
  }
  if (summary.missingPhoneCount > 0) {
    return '${summary.missingPhoneCount} بدون رقم جوال';
  }
  return 'راجع الاسم وبيانات التواصل';
}

String _pendingGuestsLabel(int count) {
  return switch (count) {
    1 => 'ضيف واحد بانتظار الرد',
    2 => 'ضيفان بانتظار الرد',
    >= 3 && <= 10 => '$count ضيوف بانتظار الرد',
    _ => '$count ضيفًا بانتظار الرد',
  };
}

Set<String> _duplicateGuests(List<Guest> guests) {
  final firstByPhone = <String, String>{};
  final duplicates = <String>{};
  for (final guest in guests) {
    final key = PhoneNumberUtils.comparisonKey(guest.phone);
    if (key == null) continue;
    final first = firstByPhone[key];
    if (first == null) {
      firstByPhone[key] = guest.id;
    } else {
      duplicates.add(first);
      duplicates.add(guest.id);
    }
  }
  return duplicates;
}

String _groupLabel(Guest guest, List<GuestGroup> groups) {
  final groupId = guest.groupId;
  if (groupId == null || groupId.trim().isEmpty) return 'بدون مجموعة';
  for (final group in groups) {
    if (group.id == groupId) return group.name;
  }
  return 'ضمن مجموعة';
}

String _attendanceFromStatus(String status) {
  return switch (status) {
    'CONFIRMED' => 'CONFIRMED',
    'DECLINED' => 'DECLINED',
    _ => 'PENDING',
  };
}

String _listTitle(_GuestFilter filter) {
  return switch (filter) {
    _GuestFilter.all => 'قائمة الضيوف',
    _GuestFilter.confirmed => 'الضيوف المؤكدون',
    _GuestFilter.pending => 'بانتظار الرد',
    _GuestFilter.declined => 'لن يحضر',
    _GuestFilter.incomplete => 'ناقص بيانات',
    _GuestFilter.groom => 'طرف العريس',
    _GuestFilter.bride => 'طرف العروسة',
  };
}

String _emptyGuestsMessage(_GuestFilter filter) {
  return switch (filter) {
    _GuestFilter.all => AarastV3Copy.firstGuestMessage,
    _GuestFilter.confirmed => 'لا يوجد ضيوف مؤكدون بعد.',
    _GuestFilter.pending => 'لا يوجد ضيوف بانتظار الرد الآن.',
    _GuestFilter.declined => 'لا يوجد ضيوف اعتذروا عن الحضور.',
    _GuestFilter.incomplete => 'لا يوجد ضيوف ناقصو البيانات الآن.',
    _GuestFilter.groom => 'لا يوجد ضيوف من طرف العريس بعد.',
    _GuestFilter.bride => 'لا يوجد ضيوف من طرف العروسة بعد.',
  };
}

String _emptyGuestsTitle(_GuestFilter filter) {
  return switch (filter) {
    _GuestFilter.all => AarastV3Copy.firstGuestTitle,
    _ => 'لا توجد نتائج في هذا القسم',
  };
}

class _GuestIssue {
  const _GuestIssue({
    required this.label,
    required this.detail,
    required this.filter,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String detail;
  final _GuestFilter filter;
  final IconData icon;
  final AarastV3AttentionTone tone;
}
