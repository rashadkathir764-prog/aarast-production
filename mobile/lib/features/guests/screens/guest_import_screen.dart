import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_duplicate_utils.dart';
import '../../../core/contacts/contact_picker_service.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/utils/arabic_sort.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/utils/name_letter.dart';
import '../../../shared/models/contact_phone_draft.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../wedding_plans/wedding_plans_api.dart' show publishGuestPlanPulse;
import '../models/guest.dart';
import '../models/guest_import.dart';
import '../providers/guests_provider.dart';
import '../utils/guest_display.dart';
import '../widgets/guest_search_field.dart';

/// Where the guests come from.
enum GuestImportSource { contacts, paste }

/// e03 «من جهات الاتصال» and w28 «أضف مجموعة ضيوف»: many guests at once.
/// Whoever the plan already has is marked and never added twice; the
/// chosen group applies to all of them.
class GuestImportScreen extends StatefulWidget {
  const GuestImportScreen({
    required this.weddingPlanId,
    required this.source,
    this.loadContacts = ContactPickerService.loadAll,
    this.confirmAccess = ContactPickerService.confirmAccess,
    super.key,
  });

  final String weddingPlanId;
  final GuestImportSource source;

  /// D112 (Q-10): the app's own page before the address book is read, said
  /// yes to; tests pass their own.
  final Future<bool> Function(BuildContext context) confirmAccess;

  /// The address book; tests pass their own.
  final Future<List<ContactPhoneDraft>> Function() loadContacts;

  @override
  State<GuestImportScreen> createState() => _GuestImportScreenState();
}

class _GuestImportScreenState extends State<GuestImportScreen> {
  final _paste = TextEditingController();
  List<ContactPhoneDraft>? _contacts;
  String? _contactsError;
  final _picked = <int>{};

  /// Pasted names the person said are someone else than the guest of the
  /// same name already on the list, by the name as compared.
  final _anotherPerson = <String>{};

  static String _nameKey(GuestCandidate candidate) =>
      ContactDuplicateUtils.normalizeName(candidate.name);
  String _query = '';
  String? _groupId;
  bool _saving = false;

  bool get _fromContacts => widget.source == GuestImportSource.contacts;

  @override
  void initState() {
    super.initState();
    _paste.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GuestsProvider>();
      if (provider.guests.every(
        (guest) => guest.weddingPlanId != widget.weddingPlanId,
      )) {
        provider.loadGuests(widget.weddingPlanId);
      }
    });
    if (_fromContacts) _loadContacts();
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _contacts = null;
      _contactsError = null;
    });
    try {
      // The names are read only after the person said yes to what is read
      // and kept (D112, Q-10); «مو الآن» reads nothing.
      if (!await widget.confirmAccess(context)) {
        if (mounted) {
          setState(
            () => _contactsError =
                'ما قرأنا جهات الاتصال. تقدر تضيف الأسماء بالكتابة أو اللصق.',
          );
        }
        return;
      }
      final contacts = await widget.loadContacts();
      if (mounted) setState(() => _contacts = contacts);
    } on ContactPickerException catch (error) {
      if (mounted) setState(() => _contactsError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _contactsError = 'ما قدرنا نقرأ جهات الاتصال');
      }
    }
  }

  List<GuestCandidate> _candidates(List<Guest> guests) {
    final people = _fromContacts
        ? [
            for (final contact in _contacts ?? const <ContactPhoneDraft>[])
              (name: contact.name, phone: contact.rawPhone),
          ]
        : parseGuestLines(_paste.text);
    return markGuestCandidates(people, guests);
  }

  /// Who the button adds: every new line pasted (a name already on the list
  /// once said to be someone else), or every new contact ticked.
  List<GuestCandidate> _toAdd(List<GuestCandidate> candidates) => [
    for (var i = 0; i < candidates.length; i++)
      if (!candidates[i].isDuplicate &&
          (_fromContacts
              ? _picked.contains(i)
              : candidates[i].sameName == null ||
                    _anotherPerson.contains(_nameKey(candidates[i]))))
        candidates[i],
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final guests = provider.guests
        .where((guest) => guest.weddingPlanId == widget.weddingPlanId)
        .toList();
    final candidates = _candidates(guests);
    final toAdd = _toAdd(candidates);
    final words = GuestWords.of(context);
    final say = words.profile.say;
    final count = words.count(toAdd.length);

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x4,
              AarastV3Space.x2,
              AarastV3Space.x2,
              0,
            ),
            child: JourneySubHeader(
              title: _fromContacts
                  ? 'من جهات الاتصال'
                  : '${say('أضف', 'أضيفي')} مجموعة '
                        '${words.profile.plan('ضيوف', 'ضيفات')}',
              subtitle: _fromContacts
                  ? say(
                      'اختر مين تعزم، والمكرر نعلّمه لك',
                      'اختاري مين تعزمين، والمكرر نعلّمه لك',
                    )
                  : say('الصق قائمة، ونفهمها لك', 'الصقي قائمة، ونفهمها لك'),
              onBack: () =>
                  context.popOrGo(AppRouter.guestList(widget.weddingPlanId)),
            ),
          ),
          Expanded(
            child: _fromContacts
                // D80: the groups this reader may put guests in, as the add
                // sheet offers; an owner's group refused a helper's import.
                ? _contactsBody(candidates, provider.editableGroups)
                : _pasteBody(candidates, provider.editableGroups),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const ValueKey('import-add'),
              label: toAdd.isEmpty
                  ? say('أضف', 'أضيفي')
                  : '${say('أضف', 'أضيفي')} $count',
              icon: LucideIcons.userPlus,
              background: context.accent.primary,
              expand: true,
              large: true,
              onPressed: toAdd.isEmpty || _saving
                  ? null
                  : () => _add(provider, toAdd),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pasteBody(List<GuestCandidate> candidates, List<GuestGroup> groups) {
    return ListView(
      padding: AarastV3Density.pageInsets,
      children: [
        JourneyTextField(
          key: const ValueKey('import-paste'),
          // The reader pastes; the names are the plan's guests.
          label:
              '${context.say('الصق', 'الصقي')} قائمة: اسم في كل سطر، '
              '${context.planWord('ورقمه', 'ورقمها')} لو عندك',
          hint: context.planWord(
            'عبدالله الحمدي 771234567\nيحيى السنيدار',
            'عبير الحمدي 771234567\nهدى السنيدار',
          ),
          controller: _paste,
          icon: LucideIcons.clipboardList,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 5,
          maxLines: 10,
          autofocus: true,
        ),
        if (candidates.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x2),
          const JourneySectionTitle('فهمناها كذا'),
          JourneyBox(
            padding: EdgeInsets.zero,
            child: JourneyList(
              children: [
                for (var i = 0; i < candidates.length; i++)
                  _CandidateRow(
                    key: ValueKey('import-line-$i'),
                    candidate: candidates[i],
                    anotherPerson: _anotherPerson.contains(
                      _nameKey(candidates[i]),
                    ),
                    onTap: candidates[i].sameName == null
                        ? null
                        : () => setState(() {
                            final key = _nameKey(candidates[i]);
                            if (!_anotherPerson.remove(key)) {
                              _anotherPerson.add(key);
                            }
                          }),
                  ),
              ],
            ),
          ),
        ],
        _groupChoice(groups),
      ],
    );
  }

  Widget _contactsBody(
    List<GuestCandidate> candidates,
    List<GuestGroup> groups,
  ) {
    if (_contactsError case final error?) {
      return Padding(
        padding: const EdgeInsets.all(AarastV3Space.x4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            JourneyNote(
              key: const ValueKey('import-error'),
              text: error,
              icon: LucideIcons.contact,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
            const SizedBox(height: AarastV3Space.x3),
            JourneyButton(
              key: const ValueKey('import-retry'),
              label: context.say('جرّب مرة ثانية', 'جرّبي مرة ثانية'),
              icon: LucideIcons.refreshCw,
              onPressed: _loadContacts,
            ),
          ],
        ),
      );
    }
    final contacts = _contacts;
    if (contacts == null) {
      return const Center(child: AarastInlineSpinner(dimension: 28));
    }
    if (contacts.isEmpty) {
      return Center(
        child: Text(
          'ما في جهات اتصال لها رقم.',
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
        ),
      );
    }

    final query = PhoneNumberUtils.toAsciiDigits(_query);
    // The name is matched on its sort key: these names come straight from
    // the phone book, where «أحمد» and «احمد» and «عبد الله» are all
    // written as their owner felt like writing them.
    final name = arabicSearchKey(query);
    bool matches(int i) =>
        query.isEmpty ||
        (name.isNotEmpty &&
            arabicSearchKey(candidates[i].name).contains(name)) ||
        contacts[i].rawPhone.replaceAll(RegExp(r'\D'), '').contains(query);
    final sections = [
      for (final section in groupByFamily([
        for (final candidate in candidates) candidate.name,
      ]))
        (
          family: section.family,
          members: section.members.where(matches).toList(),
        ),
    ]..removeWhere((section) => section.members.isEmpty);

    final items = <Widget>[
      GuestSearchField(
        autofocus: false,
        onChanged: (value) => setState(() => _query = value),
      ),
      _groupChoice(groups),
      const SizedBox(height: AarastV3Space.x1),
    ];
    for (final section in sections) {
      // «اختر الكل» takes the new ones; a name already on the list is ticked
      // one by one, by whoever knows it is someone else (RA-MO-72).
      final open = section.members
          .where(
            (i) => !candidates[i].isDuplicate && candidates[i].sameName == null,
          )
          .toList();
      final allPicked = open.isNotEmpty && open.every(_picked.contains);
      final family = section.family;
      items.add(
        JourneySectionTitle(
          family == null
              ? context.say('الباقين', 'الباقيات')
              : '$family · ${section.members.length} من جهاتك',
          action: open.isEmpty
              ? null
              : (allPicked
                    ? context.say('شيل الكل', 'شيلي الكل')
                    : context.say('اختر الكل', 'اختاري الكل')),
          onAction: open.isEmpty
              ? null
              : () => setState(() {
                  if (allPicked) {
                    _picked.removeAll(open);
                  } else {
                    _picked.addAll(open);
                  }
                }),
        ),
      );
      for (final i in section.members) {
        items.add(
          _CandidateRow(
            key: ValueKey('import-contact-$i'),
            candidate: candidates[i],
            picked: _picked.contains(i),
            // Ticked, a same name is said to be someone else.
            anotherPerson: _picked.contains(i),
            onTap: candidates[i].isDuplicate
                ? null
                : () => setState(() {
                    if (!_picked.remove(i)) _picked.add(i);
                  }),
          ),
        );
      }
    }
    return ListView.builder(
      padding: AarastV3Density.pageInsets,
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  /// «المجموعة:» for everyone added now; plans on this phone only have none.
  Widget _groupChoice(List<GuestGroup> groups) {
    if (groups.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AarastV3Space.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'المجموعة:',
            style: JourneyType.of(
              JourneyType.body,
              weight: JourneyType.bold,
              color: AarastV3Color.textMuted,
            ),
          ),
          const SizedBox(height: AarastV3Space.x2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              JourneyChip(
                key: const ValueKey('import-group-none'),
                label: 'بدون مجموعة',
                selected: _groupId == null,
                selectedColor: context.accent.primary,
                onTap: () => setState(() => _groupId = null),
              ),
              for (final group in groups)
                JourneyChip(
                  key: ValueKey('import-group-${group.id}'),
                  label: group.name,
                  selected: _groupId == group.id,
                  selectedColor: context.accent.primary,
                  onTap: () => setState(() => _groupId = group.id),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _add(GuestsProvider provider, List<GuestCandidate> toAdd) async {
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    final added = await provider.addGuests(
      weddingPlanId: widget.weddingPlanId,
      people: [
        for (final candidate in toAdd)
          (name: candidate.name, phone: candidate.phone),
      ],
      groupId: _groupId,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (added == 0) {
      AarastToast.showError(
        context,
        provider.errorMessage ??
            context.planWord('ما قدرنا نضيف الضيوف', 'ما قدرنا نضيف الضيفات'),
      );
      return;
    }
    publishGuestPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
    // Some went and some were refused: the page stays with the reason. The
    // ones added are on the list now and read «موجود من قبل», so trying
    // again adds only the refused ones, never the others twice.
    if (provider.lastRefusedGuests.isNotEmpty) {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما انضاف بعضهم. جرّب مرة ثانية.',
      );
      return;
    }
    AarastToast.showSuccess(
      context,
      'انضاف ${GuestWords.of(context).count(added)}',
    );
    context.popOrGo(AppRouter.guestList(widget.weddingPlanId));
  }
}

/// One line as understood: the name, the number or «بدون رقم», and
/// «موجود من قبل» for whoever would be added twice.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    this.picked,
    this.anotherPerson = false,
    this.onTap,
    super.key,
  });

  final GuestCandidate candidate;

  /// A name already on the list, said to be someone else: it is added.
  final bool anotherPerson;

  /// Null on the pasted list, where every new line is added.
  final bool? picked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final maybeSame = candidate.sameName != null;
    // Held back: the same person, or a same name not yet said to be another.
    final duplicate = candidate.isDuplicate || (maybeSame && !anotherPerson);
    final phone = candidate.phone;
    final detail = candidate.isDuplicate
        ? 'موجود من قبل · ما نضيفه مرتين'
        : maybeSame && !anotherPerson
        ? context.say(
            'الاسم هذا في القائمة · اضغط لو هو شخص ثاني',
            'الاسم هذا في القائمة · اضغطي لو هو شخص ثاني',
          )
        : maybeSame
        ? 'شخص ثاني بنفس الاسم · بينضاف'
        : candidate.badPhone != null
        ? 'الرقم غير صحيح · نضيفه بدون رقم'
        : phone == null
        ? 'بدون رقم'
        : PhoneNumberUtils.directionalDisplay(phone) ?? phone;
    final name = candidate.name.trim();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: AarastV3Density.chipInsets,
        child: Row(
          children: [
            JourneyAvatar(
              letter: nameLetter(name),
              color: duplicate
                  ? AarastV3Color.textFaint
                  : context.accent.primary,
              size: 36,
            ),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                      color: duplicate
                          ? AarastV3Color.textMuted
                          : AarastV3Color.ink,
                    ),
                  ),
                  Text(
                    detail,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: duplicate || candidate.badPhone != null
                          ? AarastV3Color.brandAccentStrong
                          : AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (picked case final isPicked?)
              Icon(
                // Only the same person is shut; a same name can be ticked.
                candidate.isDuplicate
                    ? LucideIcons.minusCircle
                    : isPicked
                    ? LucideIcons.checkCircle2
                    : LucideIcons.circle,
                color: isPicked
                    ? context.accent.primary
                    : AarastV3Color.textFaint,
                semanticLabel: isPicked ? 'مختار' : 'غير مختار',
              ),
          ],
        ),
      ),
    );
  }
}
