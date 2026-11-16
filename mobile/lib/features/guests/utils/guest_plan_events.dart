import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../wedding_day/wedding_day_api.dart'
    show PlanEvent, PlanEventType, PlanEventsProvider, showPlanEventSheet;
import '../models/guest.dart';
import '../models/guest_invitations.dart';
import '../widgets/guest_form_sheet.dart';

// D83: the plan's events beyond the wedding, as the guests screens offer
// them. Planning keeps the events (b12); here they are read only.

/// The events a guest can be invited to on top of the wedding, in the plan's
/// order; empty until the plan's events are read, or when it has none.
/// [listen] is false outside `build` (opening a sheet from a tap).
List<GuestFormEvent> guestFormEventsOf(
  BuildContext context,
  String weddingPlanId, {
  bool listen = true,
}) {
  final view = Provider.of<PlanEventsProvider?>(
    context,
    listen: listen,
  )?.viewOf(weddingPlanId);
  if (view == null) return const [];
  final profile = context.journeyProfile;
  return [
    for (final event in view.items)
      if (event.id case final id? when event.type != PlanEventType.wedding)
        GuestFormEvent(id: id, label: guestEventLabel(event, profile)),
  ];
}

/// The event's own name, else its kind's («الغداء»).
String guestEventLabel(PlanEvent event, JourneyProfile profile) {
  final title = event.title?.trim() ?? '';
  return title.isNotEmpty ? title : event.type.label(profile);
}

/// Where the server's word for an event's kind differs from the app's own
/// (the bride's «النسمة» is spelt alike on both since D116).
const _serverEventWords = {PlanEventType.custom: 'مناسبة'};

/// D116: the plan's occasions as the guests tab reads them: the wedding
/// first, the others by day (an undated one last). A plan whose wedding row
/// the phone has not read stands it at the id the server gives one it makes
/// (`wedding_<plan>`), so what was told of it still matches.
List<PlanEvent> planOccasions(List<PlanEvent> items, String weddingPlanId) {
  final wedding =
      items.where((event) => event.isMain).firstOrNull ??
      const PlanEvent(id: null, type: PlanEventType.wedding);
  final others =
      items.where((event) => !event.isMain && event.id != null).toList()
        ..sort((a, b) {
          final da = a.date;
          final db = b.date;
          if (da == null) return db == null ? 0 : 1;
          if (db == null) return -1;
          final byDay = da.compareTo(db);
          return byDay != 0 ? byDay : a.startMinutes - b.startMinutes;
        });
  return [wedding, ...others];
}

/// [planOccasions] of the plan's events as read on this phone; [listen] is
/// false outside `build`.
List<PlanEvent> planOccasionsOf(
  BuildContext context,
  String weddingPlanId, {
  bool listen = true,
}) => planOccasions(
  Provider.of<PlanEventsProvider?>(
        context,
        listen: listen,
      )?.viewOf(weddingPlanId)?.items ??
      const [],
  weddingPlanId,
);

/// The id an occasion is known by in what the guest was told.
String occasionKey(PlanEvent event, String weddingPlanId) =>
    event.id ?? 'wedding_$weddingPlanId';

/// D116: one guest's place in one occasion.
class GuestOccasion {
  const GuestOccasion({
    required this.event,
    required this.key,
    required this.invite,
    required this.standing,
    this.told,
  });

  final PlanEvent event;
  final String key;
  final InviteAnswer invite;
  final OccasionStanding standing;
  final GuestToldOccasion? told;

  bool get isWedding => event.isMain;
}

/// D116: [guest]'s occasions among [occasions] (from [planOccasions]): the
/// wedding always, the others they are invited to, each with where they
/// stand, worked out as the server works it out (guest_invitations.dart).
List<GuestOccasion> guestOccasions(
  Guest guest,
  List<PlanEvent> occasions,
  String weddingPlanId,
) {
  final replies = {for (final reply in guest.events) reply.planEventId: reply};
  final told = {for (final entry in guest.told) entry.planEventId: entry};
  return [
    for (final event in occasions)
      if (event.isMain || replies.containsKey(event.id))
        () {
          final key = occasionKey(event, weddingPlanId);
          final reply = replies[event.id];
          final invite = event.isMain
              ? InviteAnswer(
                  planEventId: key,
                  attendanceStatus: guest.isConfirmed
                      ? 'CONFIRMED'
                      : guest.isDeclined
                      ? 'DECLINED'
                      : 'PENDING',
                  companionsCount: guest.companionsCount,
                  answeredVersion: guest.weddingAnsweredVersion,
                )
              : InviteAnswer(
                  planEventId: key,
                  attendanceStatus: reply!.attendanceStatus,
                  companionsCount: reply.companionsCount,
                  answeredVersion: reply.answeredVersion,
                );
          final toldEntry = told[key];
          return GuestOccasion(
            event: event,
            key: key,
            invite: invite,
            told: toldEntry,
            standing: occasionStanding(
              invite,
              event.version,
              toldEntry == null
                  ? null
                  : ToldVersion(
                      version: toldEntry.version,
                      at: toldEntry.at,
                      remindedAt: toldEntry.remindedAt,
                    ),
            ),
          );
        }(),
  ];
}

/// D116: [guest]'s place in the occasion keyed [key], or null when they are
/// not invited to it.
GuestOccasion? guestOccasion(
  Guest guest,
  List<PlanEvent> occasions,
  String weddingPlanId,
  String key,
) {
  for (final entry in guestOccasions(guest, occasions, weddingPlanId)) {
    if (entry.key == key) return entry;
  }
  return null;
}

/// D116: the occasion's figures among [guests], as the server would count.
OccasionCounts occasionCountsOf(
  Iterable<Guest> guests,
  List<PlanEvent> occasions,
  String weddingPlanId,
  String key,
) {
  return occasionCounts([
    for (final guest in guests)
      if (guestOccasion(guest, occasions, weddingPlanId, key) case final entry?)
        (
          standing: entry.standing,
          companionsCount: entry.invite.companionsCount,
        ),
  ]);
}

/// The plan's place as the server writes it where an occasion has no place
/// of its own (`locationLabel`: the medium label, else the display one;
/// the city only for a plan without a location). The preview said the city
/// alone while the guest got «أمانة العاصمة، صنعاء، حدة».
String? planPlaceLabel(Map<String, dynamic>? location, String? city) {
  for (final label in [
    location?['mediumLabel'],
    location?['displayLabel'],
    city,
  ]) {
    final text = label?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return null;
}

/// D116: the occasion as the server's text names it.
InvitationOccasionText occasionText(
  PlanEvent event,
  JourneyProfile profile, {
  DateTime? weddingDate,
  String? fallbackPlace,
}) {
  final title = event.title?.trim() ?? '';
  return InvitationOccasionText(
    label: title.isNotEmpty
        ? title
        : _serverEventWords[event.type] ?? event.type.label(profile),
    isWedding: event.isMain,
    date: event.isMain ? weddingDate : event.date,
    timeSlot: event.slot?.wire,
    exactTime: event.exactTime,
    placeLabel: (event.placeLabel?.trim().isNotEmpty ?? false)
        ? event.placeLabel
        : (event.isMain ? fallbackPlace : null),
    address: event.address,
    mapUrl: event.mapUrl,
  );
}

/// D116: makes an occasion from the guest form (the occasion sheet itself)
/// and gives back the one made, to be chosen for the guest; null when none
/// was made or occasions are not read.
Future<GuestFormEvent?> addOccasionFromForm(
  BuildContext context,
  String weddingPlanId,
) async {
  final events = context.read<PlanEventsProvider?>();
  if (events == null) return null;
  final before = {
    for (final event
        in events.viewOf(weddingPlanId)?.items ?? const <PlanEvent>[])
      ?event.id,
  };
  final profile = context.journeyProfile;
  await showPlanEventSheet(
    context,
    weddingPlanId: weddingPlanId,
    provider: events,
  );
  final made = (events.viewOf(weddingPlanId)?.items ?? const <PlanEvent>[])
      .where(
        (event) =>
            event.id != null && !event.isMain && !before.contains(event.id),
      )
      .firstOrNull;
  return made == null
      ? null
      : GuestFormEvent(id: made.id!, label: guestEventLabel(made, profile));
}

/// Reads the plan's events once for the guests screens, when nobody has.
void readPlanEventsOnce(BuildContext context, String weddingPlanId) {
  final events = context.read<PlanEventsProvider?>();
  if (events == null || events.viewOf(weddingPlanId) != null) return;
  events.load(weddingPlanId);
}
