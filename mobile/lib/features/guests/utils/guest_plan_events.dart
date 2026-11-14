import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../wedding_day/wedding_day_api.dart'
    show PlanEvent, PlanEventSlot, PlanEventType, PlanEventsProvider;
import '../models/guest.dart';
import '../models/guest_invite_text.dart';
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

/// The event's time as the guest reads it (the server's planEventTimeLabel):
/// «الساعة 20:30», or the time of day; null when neither was saved.
String? guestTimeLabel(PlanEvent? event) {
  final exact = event?.exactTime?.trim() ?? '';
  if (exact.isNotEmpty) return 'الساعة $exact';
  final slot = event?.slot;
  return slot == null || slot == PlanEventSlot.exact ? null : slot.label;
}

/// [guest]'s occasions beyond the wedding, in the plan's order, worded as
/// the server's message lists them (PLAN_EVENT_LABELS, whenLine).
List<GuestInviteOccasion> guestInviteOccasions(
  Guest guest,
  List<PlanEvent> planEvents,
  JourneyProfile profile,
) {
  final invited = guest.eventIds.toSet();
  return [
    for (final event in planEvents)
      if (event.type != PlanEventType.wedding && invited.contains(event.id))
        GuestInviteOccasion(
          label: (event.title?.trim().isNotEmpty ?? false)
              ? event.title!.trim()
              : _serverEventWords[event.type] ?? event.type.label(profile),
          when: [
            if (event.date case final date?) guestMessageDay(date),
            ?guestTimeLabel(event),
          ].join(' '),
          place: event.placeLabel,
        ),
  ];
}

/// Where the server's word for an event's kind differs from the app's own.
const _serverEventWords = {
  PlanEventType.nashma: 'النشمة',
  PlanEventType.custom: 'مناسبة',
};

/// Reads the plan's events once for the guests screens, when nobody has.
void readPlanEventsOnce(BuildContext context, String weddingPlanId) {
  final events = context.read<PlanEventsProvider?>();
  if (events == null || events.viewOf(weddingPlanId) != null) return;
  events.load(weddingPlanId);
}
