part of 'guest_list_screen.dart';

const _allGroups = '*';
const _noGroup = '';

/// What the page lists under its header (RA-MO-16): fixed [widgets], then
/// the guest [rows], which the page builds only as they scroll in, so every
/// name of a list of hundreds is reached by scrolling.
class _ListPart {
  const _ListPart(
    this.widgets, [
    this.rows = const [],
    this.duplicates = const {},
  ]);

  final List<Widget> widgets;
  final List<Guest> rows;
  final Set<String> duplicates;
}

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
    _ReplyFilter.all => guests,
    _ReplyFilter.confirmed => guests.where((g) => g.isConfirmed).toList(),
    _ReplyFilter.pending => guests.where((g) => g.isPending).toList(),
    _ReplyFilter.declined => guests.where((g) => g.isDeclined).toList(),
    // A number the owner keeps (D80) is not a missing one.
    _ReplyFilter.noPhone => guests.where((g) => g.missesPhone).toList(),
  };
}

/// What the page derives from one version of the plan's guests and groups,
/// worked out once and kept until the provider replaces either list
/// (RA-MO-363): the index, the summary, each group's guests and their
/// counts, and the last search.
class _Derived {
  _Derived(this.index, this.groups);

  final GuestListIndex index;
  final List<GuestGroup> groups;

  bool holds(GuestListIndex other, List<GuestGroup> otherGroups) =>
      identical(index, other) && identical(groups, otherGroups);

  late final GuestSummary summary = GuestSummary.fromGuests(
    weddingPlanId: index.weddingPlanId,
    guests: index.guests,
    groups: groups,
  );

  /// The guests of each group by name; [_noGroup] holds those in none (or
  /// in a group since removed), [_allGroups] everyone.
  late final Map<String, List<Guest>> _byGroup = () {
    final known = {for (final group in groups) group.id};
    final byGroup = <String, List<Guest>>{_allGroups: index.sorted};
    for (final guest in index.sorted) {
      final id = guest.groupId;
      final key = id != null && known.contains(id) ? id : _noGroup;
      (byGroup[key] ??= []).add(guest);
    }
    return byGroup;
  }();

  List<Guest> inGroup(String key) => _byGroup[key] ?? const [];

  final _counts = <String, Map<_ReplyFilter, int>>{};
  final _visible = <(String, _ReplyFilter), List<Guest>>{};

  /// Each answer chip's count in [group].
  Map<_ReplyFilter, int> countsIn(String group) => _counts[group] ??= {
    for (final filter in _ReplyFilter.values)
      filter: _filtered(inGroup(group), filter).length,
  };

  /// [group]'s guests under [filter], by name.
  List<Guest> visibleIn(String group, _ReplyFilter filter) =>
      _visible[(group, filter)] ??= _filtered(inGroup(group), filter);

  String? _query;
  List<Guest> _found = const [];

  /// The guests [query] finds, by name.
  List<Guest> search(String query) {
    if (_query != query) {
      _query = query;
      _found = index.search(query);
    }
    return _found;
  }
}

/// «124 ضيف». A helper (D80) starts the plan's list, not their own.
/// Critique ض2 (Rashad 2026-11-17): who confirmed, who has not answered and
/// who no invitation reached are the card's, right under this line; here
/// only how many there are, the word agreeing with its count (ض1).
String _statusLine(
  GuestSummary summary,
  GuestWords words, {
  required bool helps,
}) {
  if (summary.totalGuests == 0) {
    return '${words.profile.say('ابدأ', 'ابدئي')} بقائمة '
        '${helps ? words.guests : words.yourGuests}';
  }
  return words.count(summary.totalGuests);
}

/// The empty plan said to a helper (D80): the list is the plan's, so it does
/// not say «ما أضفت أحد».
String _emptyPlanLine(BuildContext context) =>
    'ما فيه ${context.planWord('ضيوف', 'ضيفات')} في القائمة بعد';

/// «آخر تحديث قبل 20 دقيقة».
String _lastUpdate(DateTime at) {
  final minutes = appNow().difference(at).inMinutes;
  if (minutes < 1) return 'آخر تحديث الحين';
  if (minutes < 60) {
    return 'آخر تحديث قبل ${arabicCount(minutes, one: 'دقيقة', two: 'دقيقتين', few: 'دقائق', many: 'دقيقة')}';
  }
  final hours = minutes ~/ 60;
  if (hours < 24) {
    return 'آخر تحديث قبل ${arabicCount(hours, one: 'ساعة', two: 'ساعتين', few: 'ساعات', many: 'ساعة')}';
  }
  return 'آخر تحديث قبل ${arabicCount(hours ~/ 24, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}';
}

/// A family (group) with how many of its guests confirmed.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.name,
    required this.guests,
    required this.onTap,
    this.icon = LucideIcons.users,
    this.isConfirmed,
    super.key,
  });

  final String name;
  final List<Guest> guests;
  final VoidCallback onTap;
  final IconData icon;

  /// D116: whether a guest is coming to the occasion followed; the wedding's
  /// answer when not given.
  final bool Function(Guest guest)? isConfirmed;

  @override
  Widget build(BuildContext context) {
    final confirmed = isConfirmed ?? (Guest guest) => guest.isConfirmed;
    final yes = guests.where(confirmed).length;
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
          padding: const EdgeInsets.all(AarastV3Space.x3),
          child: Row(
            children: [
              JourneyIconTile(
                icon: icon,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
                size: AarastV3Size.mark,
              ),
              const SizedBox(width: AarastV3Space.x3),
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
                    const SizedBox(height: AarastV3Space.x1),
                    JourneyBar(
                      value: all == 0 ? 0 : yes / all,
                      color: context.accent.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AarastV3Space.x3),
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
    required this.emptyLine,
    required this.onContacts,
    required this.onPaste,
    required this.onOne,
  });

  /// «ما أضفت أحد بعد» on the owner's list, the plan's empty list to a
  /// helper.
  final String emptyLine;

  /// Null where the device has no address book (web, desktop).
  final VoidCallback? onContacts;
  final VoidCallback onPaste;
  final VoidCallback onOne;

  @override
  Widget build(BuildContext context) {
    Widget icon(IconData data) => Container(
      width: AarastV3Size.mark,
      height: AarastV3Size.mark,
      decoration: BoxDecoration(
        color: context.accent.primarySoft,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      ),
      child: Icon(data, color: context.accent.primary),
    );
    return Column(
      key: const ValueKey('guests-first'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AarastV3Space.x2),
        Text(
          context.say(AarastV3Copy.firstGuestTitle, 'مين بتعزمين؟'),
          style: JourneyType.of(
            JourneyType.pageTitle,
            weight: JourneyType.bold,
          ),
        ),
        const SizedBox(height: AarastV3Space.x1),
        Text(
          '$emptyLine.',
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: AarastV3Space.x4),
        if (onContacts case final contacts?) ...[
          JourneyChoiceCard(
            key: const ValueKey('guests-first-contacts'),
            choosable: false,
            title: 'من جهات الاتصال',
            subtitle: context.say(
              'تختار مين تعزم، والمكرر نعلّمه لك',
              'تختارين مين تعزمين، والمكرر نعلّمه لك',
            ),
            leading: icon(LucideIcons.contact),
            onTap: contacts,
          ),
          const SizedBox(height: AarastV3Space.x2),
        ],
        JourneyChoiceCard(
          key: const ValueKey('guests-first-paste'),
          choosable: false,
          title: context.say('الصق قائمة', 'الصقي قائمة'),
          subtitle: context.planWord(
            'اسم في كل سطر، ورقمه لو عندك',
            'اسم في كل سطر، ورقمها لو عندك',
          ),
          leading: icon(LucideIcons.clipboardList),
          onTap: onPaste,
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyChoiceCard(
          key: const ValueKey('guests-first-one'),
          choosable: false,
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
