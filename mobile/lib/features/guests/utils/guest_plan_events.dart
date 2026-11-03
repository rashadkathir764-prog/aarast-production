import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../wedding_day/wedding_day_api.dart'
    show PlanEvent, PlanEventType, PlanEventsProvider;
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

/// Reads the plan's events once for the guests screens, when nobody has.
void readPlanEventsOnce(BuildContext context, String weddingPlanId) {
  final events = context.read<PlanEventsProvider?>();
  if (events == null || events.viewOf(weddingPlanId) != null) return;
  events.load(weddingPlanId);
}
