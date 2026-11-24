import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/offline/local_plan_id.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/sync_status.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../wedding_day/wedding_day_api.dart'
    show PlanEvent, PlanEventsProvider;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider;
import '../data/guests_api.dart';
import '../models/guest.dart';
import '../models/guest_invitations.dart';
import '../models/guest_invite_text.dart';
import '../providers/guests_provider.dart';
import '../utils/guest_display.dart';
import '../utils/guest_plan_events.dart';
import '../widgets/guest_invitation_card_image.dart';
import '../widgets/invitation_message_preview.dart';
import '../widgets/invitation_queue_sheet.dart';
import 'guest_list_screen.dart' show SendAudience;

/// D116 «إرسال الدعوات»: the round of sends from the person's own WhatsApp.
/// How (one invitation with every occasion of the guest, or one for one
/// occasion), for which occasion's guests, and to whom: those never told,
/// those holding an old day or place, those told and silent. It shows the
/// text the first of them gets, and who cannot be sent to and why; the
/// round itself is [InvitationQueueSheet].
class GuestSendScreen extends StatefulWidget {
  const GuestSendScreen({
    required this.weddingPlanId,
    this.initialEvent,
    this.initialAudience,
    super.key,
  });

  final String weddingPlanId;

  /// An occasion beyond the wedding the round is about; null, all of them.
  final String? initialEvent;
  final String? initialAudience;

  @override
  State<GuestSendScreen> createState() => _GuestSendScreenState();
}

class _GuestSendScreenState extends State<GuestSendScreen> {
  /// One invitation per occasion instead of one with every occasion.
  bool _separate = false;

  /// The occasion followed; null, every occasion (one invitation only).
  late String? _eventKey = widget.initialEvent;
  late SendAudience _audience =
      SendAudience.fromWire(widget.initialAudience) ?? SendAudience.notTold;
  InvitationCard? _card;
  bool _cardLoaded = false;

  String get _planId => widget.weddingPlanId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      readPlanEventsOnce(context, _planId);
      final guests = context.read<GuestsProvider>();
      if (guests.guests.every((guest) => guest.weddingPlanId != _planId)) {
        unawaited(guests.loadGuests(_planId));
      }
      unawaited(_loadCard());
    });
  }

  Future<void> _loadCard() async {
    try {
      final card = await context.read<GuestsApi>().getInvitationCard(_planId);
      if (mounted) setState(() => _card = card);
    } on Object {
      // Without the card the text still goes, and the card step stays out.
    } finally {
      if (mounted) setState(() => _cardLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = GuestWords.of(context);
    final profile = context.journeyProfile;
    final provider = context.watch<GuestsProvider>();
    final offline =
        context.watch<OfflineSyncService?>()?.state == SyncState.offline;
    final keptOnPhone = isLocalPlanId(_planId);
    final occasions = planOccasions(
      context.watch<PlanEventsProvider?>()?.viewOf(_planId)?.items ?? const [],
      _planId,
    );
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    final plan = summary?.planId == _planId ? summary : null;
    final planTitle = plan?.title.trim().isNotEmpty == true
        ? plan!.title
        : 'زفافنا';
    final keys = {for (final event in occasions) occasionKey(event, _planId)};
    // One invitation per occasion needs an occasion: the wedding by default.
    final eventKey = keys.contains(_eventKey)
        ? _eventKey
        : (_separate ? occasionKey(occasions.first, _planId) : null);
    final guests = [
      for (final guest in provider.guests)
        if (guest.weddingPlanId == _planId && guest.editable) guest,
    ];

    /// Where [guest] stands for the occasions the round looks at.
    List<GuestOccasion> scopeOf(Guest guest) {
      final all = guestOccasions(guest, occasions, _planId);
      return eventKey == null
          ? all
          : [
              for (final entry in all)
                if (entry.key == eventKey) entry,
            ];
    }

    bool inAudience(Guest guest, SendAudience audience) =>
        scopeOf(guest).any((entry) => audience.includes(entry.standing));

    final counts = {
      for (final audience in SendAudience.values)
        audience: guests.where((guest) => inAudience(guest, audience)).length,
    };
    final chosen = [
      for (final guest in guests)
        if (inAudience(guest, _audience)) guest,
    ];
    final reachable = [
      for (final guest in chosen)
        if (guestChatCanOpen(guest.phone) && guest.hasPhone) guest,
    ];
    final noPhone = chosen.where((guest) => !guest.hasPhone).toList();
    final noCountry = chosen
        .where((guest) => guest.hasPhone && !guestChatCanOpen(guest.phone))
        .toList();

    InvitationSendKind kindFor(Guest guest) => switch (_audience) {
      SendAudience.notTold =>
        !_separate && guest.everTold
            ? InvitationSendKind.addition
            : InvitationSendKind.invitation,
      SendAudience.changed => InvitationSendKind.change,
      SendAudience.silent => InvitationSendKind.reminder,
    };
    final turns = <InvitationTurn>[
      for (final guest in reachable)
        (
          guest: guest,
          kind: kindFor(guest),
          planEventId: _separate ? eventKey : null,
        ),
    ];

    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: AarastV3Density.pageInsets,
              children: [
                JourneySubHeader(
                  title: 'إرسال الدعوات',
                  subtitle: context.say(
                    'من واتساب جوالك، ضيف بعد ضيف',
                    'من واتساب جوالك، ضيفة بعد ضيفة',
                  ),
                  onBack: () => context.popOrGo(AppRouter.guestList(_planId)),
                ),
                if (occasions.length > 1) ...[
                  // D14: the reader sends; the guests are the plan's side.
                  JourneySectionTitle(context.say('كيف ترسل؟', 'كيف ترسلين؟')),
                  JourneyOption(
                    key: const ValueKey('send-unified'),
                    title: profile.plan(
                      'دعوة وحدة فيها كل مناسباته',
                      'دعوة وحدة فيها كل مناسباتها',
                    ),
                    subtitle: profile.plan(
                      'كل ضيف يوصله نص واحد ورابط واحد، والرد لكل مناسبة',
                      'كل ضيفة يوصلها نص واحد ورابط واحد، والرد لكل مناسبة',
                    ),
                    selected: !_separate,
                    onTap: () => setState(() {
                      _separate = false;
                    }),
                  ),
                  const SizedBox(height: AarastV3Space.x2),
                  JourneyOption(
                    key: const ValueKey('send-separate'),
                    title: 'دعوة لكل مناسبة لحالها',
                    subtitle: profile.plan(
                      'نص يخص المناسبة، بنفس رابط الضيف',
                      'نص يخص المناسبة، بنفس رابط الضيفة',
                    ),
                    selected: _separate,
                    onTap: () => setState(() {
                      _separate = true;
                      _eventKey ??= occasionKey(occasions.first, _planId);
                    }),
                  ),
                  const SizedBox(height: AarastV3Space.x4),
                  JourneySectionTitle(
                    _separate
                        ? 'لأي مناسبة؟'
                        : profile.plan('ضيوف أي مناسبة؟', 'ضيفات أي مناسبة؟'),
                  ),
                  Wrap(
                    spacing: AarastV3Space.x2,
                    runSpacing: AarastV3Space.x2,
                    children: [
                      if (!_separate)
                        JourneyChip(
                          key: const ValueKey('send-event-all'),
                          label: 'كل المناسبات',
                          selected: eventKey == null,
                          selectedColor: context.accent.primary,
                          onTap: () => setState(() => _eventKey = null),
                        ),
                      for (final event in occasions)
                        JourneyChip(
                          key: ValueKey(
                            'send-event-${occasionKey(event, _planId)}',
                          ),
                          label: guestEventLabel(event, profile),
                          selected: eventKey == occasionKey(event, _planId),
                          selectedColor: context.accent.primary,
                          onTap: () => setState(
                            () => _eventKey = occasionKey(event, _planId),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AarastV3Space.x4),
                ],
                JourneySectionTitle('لمين؟'),
                Wrap(
                  spacing: AarastV3Space.x2,
                  runSpacing: AarastV3Space.x2,
                  children: [
                    for (final audience in SendAudience.values)
                      JourneyChip(
                        key: ValueKey('send-audience-${audience.wire}'),
                        label:
                            '${_audienceWords(context, audience)} ${counts[audience]}',
                        selected: _audience == audience,
                        selectedColor: context.accent.primary,
                        onTap: () => setState(() => _audience = audience),
                      ),
                  ],
                ),
                const SizedBox(height: AarastV3Space.x2),
                Text(
                  _audienceMeaning(context, _audience),
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                const SizedBox(height: AarastV3Space.x4),
                // D1 of the closing round: «وصلتهم الدعوة» is said only of a
                // list that was read.
                if (guests.isEmpty &&
                    (provider.isLoading ||
                        (!provider.hasRead(_planId) &&
                            provider.loadErrorMessage == null)))
                  const JourneyListState(
                    phase: JourneyListPhase.loading,
                    section: JourneySection.guests,
                  )
                else if (guests.isEmpty && provider.loadErrorMessage != null)
                  JourneyListState(
                    phase: JourneyListPhase.error,
                    section: JourneySection.guests,
                    onRetry: () => unawaited(
                      context.read<GuestsProvider>().loadGuests(_planId),
                    ),
                  )
                else if (chosen.isEmpty)
                  JourneyNote(
                    key: const ValueKey('send-nobody'),
                    text: switch (_audience) {
                      SendAudience.notTold =>
                        guests.isEmpty
                            ? words.noneAdded
                            : '${words.allGuests} هنا '
                                  '${words.profile.plan('وصلتهم', 'وصلتهن')} الدعوة.',
                      SendAudience.changed =>
                        'ما فيه أحد عنده موعد أو مكان قديم.',
                      SendAudience.silent => words.profile.plan(
                        'ما فيه أحد وصلته وما ردّ.',
                        'ما فيه وحدة وصلتها وما ردّت.',
                      ),
                    },
                    icon: LucideIcons.checkCircle2,
                  )
                else ...[
                  if (reachable.isNotEmpty) ...[
                    JourneySectionTitle(
                      context.planWord(
                        'اللي يوصل أول واحد',
                        'اللي يوصل أول وحدة',
                      ),
                    ),
                    _MessagePreview(
                      text: _previewText(
                        context,
                        reachable.first,
                        occasions,
                        planTitle: planTitle,
                        weddingDate: plan?.weddingDate,
                        place: planPlaceLabel(plan?.location, plan?.city),
                        kind: kindFor(reachable.first),
                        eventKey: _separate ? eventKey : null,
                      ),
                    ),
                    const SizedBox(height: AarastV3Space.x2),
                    Text(
                      _cardLine(context),
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    const SizedBox(height: AarastV3Space.x4),
                    JourneySectionTitle(
                      'تروح لـ${words.count(reachable.length)}',
                    ),
                    Text(
                      reachable.map((guest) => guest.name).join('، '),
                      style: JourneyType.of(JourneyType.small),
                    ),
                  ],
                  if (noPhone.isNotEmpty || noCountry.isNotEmpty) ...[
                    const SizedBox(height: AarastV3Space.x4),
                    JourneyNote(
                      key: const ValueKey('send-unreachable'),
                      text: [
                        if (noPhone.isNotEmpty)
                          'بلا رقم: ${noPhone.map((guest) => guest.name).join('، ')}',
                        if (noCountry.isNotEmpty)
                          'رقم بلا مفتاح الدولة: ${noCountry.map((guest) => guest.name).join('، ')}',
                      ].join('\n'),
                      icon: LucideIcons.phoneOff,
                      color: AarastV3Color.textMuted,
                      soft: AarastV3Color.paper,
                    ),
                  ],
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AarastV3Space.x4,
                AarastV3Space.x2,
                AarastV3Space.x4,
                AarastV3Space.x4,
              ),
              child: JourneyButton(
                key: const ValueKey('send-start'),
                // A plan kept on the phone has no links to send (the tab
                // says so and offers no round); opened by its address, the
                // screen sends nothing either.
                label: keptOnPhone
                    ? context.say(
                        'الإرسال يشتغل لما تحفظ خطتك برقمك',
                        'الإرسال يشتغل لما تحفظين خطتك برقمك',
                      )
                    : offline
                    ? 'الإرسال يحتاج نت'
                    : turns.isEmpty
                    ? context.say('ما فيه أحد ترسل له', 'ما فيه أحد ترسلين له')
                    : '${context.say('ابدأ', 'ابدئي')} الإرسال · ${words.count(turns.length)}',
                icon: LucideIcons.send,
                large: true,
                expand: true,
                onPressed: keptOnPhone || offline || turns.isEmpty
                    ? null
                    : () => _start(
                        turns,
                        occasions,
                        eventKey: _separate ? eventKey : null,
                        planTitle: planTitle,
                        weddingDate: plan?.weddingDate,
                        place: planPlaceLabel(plan?.location, plan?.city),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cardLine(BuildContext context) {
    if (!_cardLoaded) return '';
    final card = _card;
    if (card?.isReadyCard == true && card?.photoUrl != null) {
      return 'وبعد النص تروح بطاقتك الجاهزة صورة.';
    }
    return context.planWord(
      'وبعد النص تروح البطاقة صورة، باسم الضيف ومناسباته.',
      'وبعد النص تروح البطاقة صورة، باسم الضيفة ومناسباتها.',
    );
  }

  Future<void> _start(
    List<InvitationTurn> turns,
    List<PlanEvent> occasions, {
    required String planTitle,
    String? eventKey,
    DateTime? weddingDate,
    String? place,
  }) async {
    final api = context.read<GuestsApi>();
    final profile = context.journeyProfile;
    final card = _card;
    final ready = card?.isReadyCard == true ? card?.photoUrl : null;
    final photo = card?.isReadyCard == false && card?.photoUrl != null
        ? invitationPhoto(card!.photoUrl!)
        : null;
    final host = invitationHostPhrase(card?.hostLine, bride: profile.isBride);
    await showJourneySheet<int>(
      context: context,
      isDismissible: false,
      builder: (_) => InvitationQueueSheet(
        turns: turns,
        api: api,
        title: 'إرسال الدعوات',
        readyCard: ready == null ? null : () => _download(ready),
        cardFor: ready != null
            ? null
            : (guest) => GuestInvitationCardImage(
                planTitle: planTitle,
                hostPhrase: host,
                freeText: card?.freeText,
                guestName: guest.name,
                photo: photo,
                // An invitation for one occasion draws that occasion alone,
                // as its text names it alone.
                occasions: [
                  for (final entry in guestOccasions(guest, occasions, _planId))
                    if (eventKey == null || entry.key == eventKey)
                      occasionText(
                        entry.event,
                        profile,
                        weddingDate: weddingDate,
                        fallbackPlace: place,
                      ),
                ],
              ),
      ),
    );
    if (!mounted) return;
    // What was sent is the server's now: the list reads it again.
    unawaited(context.read<GuestsProvider>().loadGuests(_planId));
  }

  /// The ready card's bytes, read through its short signed link.
  Future<Uint8List?> _download(String url) async {
    try {
      final data = await NetworkAssetBundle(Uri.parse(url)).load(url);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on Object {
      return null;
    }
  }
}

// D14: the guests are the plan's side («وصلتهم» / «وصلتهن»).
String _audienceWords(BuildContext context, SendAudience audience) =>
    switch (audience) {
      SendAudience.notTold => context.planWord('ما وصلتهم', 'ما وصلتهن'),
      SendAudience.changed => context.planWord('تغيّر عليهم', 'تغيّر عليهن'),
      SendAudience.silent => context.planWord('ما ردّوا', 'ما ردّن'),
    };

String _audienceMeaning(
  BuildContext context,
  SendAudience audience,
) => switch (audience) {
  SendAudience.notTold => context.planWord(
    'ما انرسلت لهم دعوة بعد، أو فيه مناسبة انضافت لهم بعد ما وصلتهم.',
    'ما انرسلت لهن دعوة بعد، أو فيه مناسبة انضافت لهن بعد ما وصلتهن.',
  ),
  SendAudience.changed => context.planWord(
    'وصلهم موعد أو مكان تغيّر بعدها؛ يوصلهم الجديد، ومن أكّد يؤكّد من جديد.',
    'وصلهن موعد أو مكان تغيّر بعدها؛ يوصلهن الجديد، واللي أكّدت تؤكّد من جديد.',
  ),
  SendAudience.silent => context.planWord(
    'وصلتهم الدعوة وما ردّوا؛ يوصلهم تذكير برابطهم.',
    'وصلتهن الدعوة وما ردّن؛ يوصلهن تذكير برابطهن.',
  ),
};

/// The text the first guest of the round gets, word for word as the
/// server builds it (guest_invitations.dart), with a sample link.
String _previewText(
  BuildContext context,
  Guest guest,
  List<PlanEvent> occasions, {
  required String planTitle,
  required InvitationSendKind kind,
  DateTime? weddingDate,
  String? place,
  String? eventKey,
}) {
  final profile = context.journeyProfile;
  final entries = guestOccasions(guest, occasions, guest.weddingPlanId);
  final scope = [
    for (final entry in entries)
      if (eventKey == null || entry.key == eventKey) entry,
  ];
  final named = occasionsToName(kind, [
    for (final entry in scope)
      (planEventId: entry.key, standing: entry.standing),
  ]).toSet();
  final toName = named.isEmpty
      ? scope
      : [
          for (final entry in scope)
            if (named.contains(entry.key)) entry,
        ];
  return invitationMessage(
    guestName: guest.name,
    planTitle: planTitle,
    url: 'https://${AppRouter.inviteAppLinkHost}/rsvp/…',
    kind: kind,
    bride: profile.isBride,
    occasions: [
      for (final entry in toName)
        occasionText(
          entry.event,
          profile,
          weddingDate: weddingDate,
          fallbackPlace: place,
        ),
    ],
    confirmed: toName.every((entry) => entry.standing.isConfirmed),
  );
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const ValueKey('send-preview'),
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: InvitationMessagePreview(text: text),
    );
  }
}
