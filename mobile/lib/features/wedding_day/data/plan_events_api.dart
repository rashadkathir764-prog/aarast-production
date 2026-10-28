import '../../../core/network/api_client.dart';
import '../../../core/utils/plan_day.dart';
import '../models/plan_event.dart';

/// b13's fields as they are saved: every field is sent, an empty one as
/// null, so the sheet's state is what the server keeps.
class PlanEventDraft {
  const PlanEventDraft({
    this.title,
    this.date,
    this.slot,
    this.exactTime,
    this.placeLabel,
    this.responsibleName,
    this.note,
  });

  final String? title;
  final DateTime? date;
  final PlanEventSlot? slot;
  final String? exactTime;
  final String? placeLabel;
  final String? responsibleName;
  final String? note;

  Map<String, dynamic> toJson({required bool isMain}) {
    String? text(String? value) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    }

    return {
      'title': text(title),
      // The wedding's day is the plan's date; it moves with «أجّل العرس».
      if (!isMain) 'date': date == null ? null : planDayToJson(date!),
      'timeSlot': slot?.wire,
      'exactTime': slot == PlanEventSlot.exact ? text(exactTime) : null,
      'placeLabel': text(placeLabel),
      'responsibleName': text(responsibleName),
      'note': text(note),
    };
  }
}

/// D65: the wedding's events (`/wedding-plans/:id/events`).
class PlanEventsApi {
  const PlanEventsApi(this._apiClient);

  final ApiClient _apiClient;

  String _base(String weddingPlanId) =>
      '/api/v1/wedding-plans/$weddingPlanId/events';

  Future<PlanEventsView> list(String weddingPlanId) async {
    return PlanEventsView.fromJson(
      await _apiClient.getJson(_base(weddingPlanId)),
    );
  }

  Future<PlanEvent> create(
    String weddingPlanId,
    PlanEventType type,
    PlanEventDraft draft,
  ) async {
    return PlanEvent.fromJson(
      await _apiClient.postJson(_base(weddingPlanId), {
        'type': type.wire,
        ...draft.toJson(isMain: type == PlanEventType.wedding),
      }),
    );
  }

  Future<PlanEvent> update(
    String weddingPlanId,
    PlanEvent event,
    PlanEventDraft draft,
  ) async {
    return PlanEvent.fromJson(
      await _apiClient.patchJson(
        '${_base(weddingPlanId)}/${event.id}',
        draft.toJson(isMain: event.isMain),
      ),
    );
  }

  Future<void> remove(String weddingPlanId, String eventId) async {
    await _apiClient.deleteJson('${_base(weddingPlanId)}/$eventId');
  }
}
