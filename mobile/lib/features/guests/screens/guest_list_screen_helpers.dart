part of 'guest_list_screen.dart';

const _allGroups = '*';
const _noGroup = '';

/// The answers a group's guests can be narrowed to.
enum _ReplyFilter { all, confirmed, pending, declined, noPhone }

extension on _ReplyFilter {
  String labelFor(GuestWords words) => switch (this) {
    _ReplyFilter.all => 'الكل',
    _ReplyFilter.confirmed => words.confirmed,
    _ReplyFilter.pending => words.pending,
    _ReplyFilter.declined => words.declined,
    _ReplyFilter.noPhone => 'بدون رقم',
  };
}

List<Guest> _filtered(List<Guest> guests, _ReplyFilter filter) {
  return switch (filter) {
    _ReplyFilter.all => List.of(guests),
    _ReplyFilter.confirmed => guests.where((g) => g.isConfirmed).toList(),
    _ReplyFilter.pending => guests.where((g) => g.isPending).toList(),
    _ReplyFilter.declined => guests.where((g) => g.isDeclined).toList(),
    _ReplyFilter.noPhone => guests.where((g) => !g.hasPhone).toList(),
  };
}

/// Guests whose name or number holds [query].
List<Guest> _search(List<Guest> guests, String query) {
  final digits = PhoneNumberUtils.toAsciiDigits(
    query,
  ).replaceAll(RegExp(r'[^0-9]'), '');
  return guests.where((guest) {
    if (guest.name.contains(query)) return true;
    if (digits.length < 3) return false;
    final phone = PhoneNumberUtils.toAsciiDigits(guest.phone ?? '');
    return phone.replaceAll(RegExp(r'[^0-9]'), '').contains(digits);
  }).toList()..sort((a, b) => a.name.compareTo(b.name));
}

/// «124 مدعو · 86 أكدوا · 20 ما ردّوا».
String _statusLine(GuestSummary summary, GuestWords words) {
  if (summary.totalGuests == 0) {
    return '${words.profile.say('ابدأ', 'ابدئي')} بقائمة ${words.yourGuests}';
  }
  return [
    '${summary.totalGuests} ${words.invited}',
    if (summary.confirmed > 0) '${summary.confirmed} ${words.confirmed}',
    if (summary.pending > 0) '${summary.pending} ${words.pending}',
  ].join(' · ');
}

/// «آخر تحديث قبل 20 دقيقة».
String _lastUpdate(DateTime at) {
  final minutes = DateTime.now().difference(at).inMinutes;
  if (minutes < 1) return 'آخر تحديث الآن';
  if (minutes < 60) {
    return 'آخر تحديث قبل ${arabicCount(minutes, one: 'دقيقة', two: 'دقيقتين', few: 'دقائق', many: 'دقيقة')}';
  }
  final hours = minutes ~/ 60;
  if (hours < 24) {
    return 'آخر تحديث قبل ${arabicCount(hours, one: 'ساعة', two: 'ساعتين', few: 'ساعات', many: 'ساعة')}';
  }
  return 'آخر تحديث قبل ${arabicCount(hours ~/ 24, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}';
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
      duplicates
        ..add(first)
        ..add(guest.id);
    }
  }
  return duplicates;
}

/// «86 أكدوا من 124», who has not answered, the three-part bar and, inside
/// the same card as e01 draws it, the reminder [action].
/// Pressing the figures opens w38 «كم بيحضر؟».
class _GuestSummaryCard extends StatelessWidget {
  const _GuestSummaryCard({
    required this.summary,
    required this.onTap,
    this.action,
  });

  final GuestSummary summary;
  final VoidCallback onTap;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final total = summary.totalGuests;
    final words = GuestWords.of(context);
    return JourneyBox(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AarastPressable(
            key: const ValueKey('guests-summary'),
            onTap: onTap,
            semanticLabel:
                'كم بيحضر؟ ${summary.confirmed} ${words.confirmed} من $total',
            borderRadius: BorderRadius.circular(12),
            child: GuestSummaryFigures(
              words: words,
              total: total,
              confirmed: summary.confirmed,
              pending: summary.pending,
              expectedSeats: summary.expectedSeatsCount,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

/// A family (group) with how many of its guests confirmed.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.name,
    required this.guests,
    required this.onTap,
    this.icon = LucideIcons.users,
    super.key,
  });

  final String name;
  final List<Guest> guests;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final yes = guests.where((guest) => guest.isConfirmed).length;
    final all = guests.length;
    final words = GuestWords.of(context);
    return Semantics(
      button: true,
      label: '$name، ${words.profile.plan('أكد', 'أكّدت')} $yes من $all',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              JourneyIconTile(
                icon: icon,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    JourneyBar(
                      value: all == 0 ? 0 : yes / all,
                      color: context.accent.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$yes/$all',
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  Text(
                    words.confirmed,
                    style: JourneyType.of(
                      JourneyType.caption,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// x21 «مين بتعزم؟»: the first guests from the contacts, a pasted list, or
/// one by one.
class _FirstGuests extends StatelessWidget {
  const _FirstGuests({
    required this.onContacts,
    required this.onPaste,
    required this.onOne,
  });

  /// Null where the device has no address book (web, desktop).
  final VoidCallback? onContacts;
  final VoidCallback onPaste;
  final VoidCallback onOne;

  @override
  Widget build(BuildContext context) {
    Widget icon(IconData data) => Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: context.accent.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(data, color: context.accent.primary),
    );
    return Column(
      key: const ValueKey('guests-first'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          context.say(AarastV3Copy.firstGuestTitle, 'مين بتعزمين؟'),
          style: JourneyType.of(JourneyType.display, weight: JourneyType.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${GuestWords.of(context).noneAdded}.',
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        if (onContacts case final contacts?) ...[
          JourneyChoiceCard(
            key: const ValueKey('guests-first-contacts'),
            title: 'من جهات الاتصال',
            subtitle: context.say(
              'تختار مين تعزم، والمكرر نعلّمه لك',
              'تختارين مين تعزمين، والمكرر نعلّمه لك',
            ),
            leading: icon(LucideIcons.contact),
            onTap: contacts,
          ),
          const SizedBox(height: 10),
        ],
        JourneyChoiceCard(
          key: const ValueKey('guests-first-paste'),
          title: context.say('الصق قائمة', 'الصقي قائمة'),
          subtitle: context.planWord(
            'اسم في كل سطر، ورقمه لو عندك',
            'اسم في كل سطر، ورقمها لو عندك',
          ),
          leading: icon(LucideIcons.clipboardList),
          onTap: onPaste,
        ),
        const SizedBox(height: 10),
        JourneyChoiceCard(
          key: const ValueKey('guests-first-one'),
          title: context.planWord('ضيف واحد', 'ضيفة وحدة'),
          subtitle: context.planWord(
            'اسمه ورقمه وكم معه',
            'اسمها ورقمها وكم معها',
          ),
          leading: icon(LucideIcons.userPlus),
          onTap: onOne,
        ),
      ],
    );
  }
}
