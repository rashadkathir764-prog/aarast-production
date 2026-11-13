import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/offline_tables.dart';
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
///
/// D85: the plan's events are read from the phone's copy when the server
/// is out of reach, and a change is kept on the phone and sent when the
/// server answers; the copy is updated at once so the home and the guests
/// see the event before it is sent.
class PlanEventsApi {
  PlanEventsApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _reads = OfflineReads(apiClient, offline),
      _writes = OfflineWrites(apiClient, offline);

  final OfflineReads _reads;
  final OfflineWrites _writes;

  String _base(String weddingPlanId) =>
      '/api/v1/wedding-plans/$weddingPlanId/events';

  String _key(String weddingPlanId) => 'plan-events:$weddingPlanId';

  Future<PlanEventsView> list(String weddingPlanId) async {
    return PlanEventsView.fromJson(
      await _reads.blob(_base(weddingPlanId), metaKey: _key(weddingPlanId)),
    );
  }

  /// The phone's copy alone, or null before the first answer.
  Future<PlanEventsView?> cachedView(String weddingPlanId) async {
    final json = await _reads.cachedBlob(_key(weddingPlanId));
    return json == null ? null : PlanEventsView.fromJson(json);
  }

  Future<PlanEvent> create(
    String weddingPlanId,
    PlanEventType type,
    PlanEventDraft draft,
  ) async {
    final payload = {
      'type': type.wire,
      ...draft.toJson(isMain: type == PlanEventType.wedding),
    };
    final localId = OfflineWrites.localId('plan-event');
    final json = await _writes.queued(
      entityType: 'plan_event',
      operation: 'create',
      method: 'POST',
      endpoint: _base(weddingPlanId),
      payload: payload,
      table: OfflineTables.cachedPlanEvents,
      localJson: {'id': localId, 'weddingPlanId': weddingPlanId, ...payload},
      planId: weddingPlanId,
      localEntityId: localId,
    );
    await _putInCopy(weddingPlanId, json);
    return PlanEvent.fromJson(json);
  }

  Future<PlanEvent> update(
    String weddingPlanId,
    PlanEvent event,
    PlanEventDraft draft,
  ) async {
    final id = event.id!;
    final payload = draft.toJson(isMain: event.isMain);
    // RA-MO-286: the sheet (and the invitation card, which saves the
    // wedding's place here) sent every field as the phone had read it, so
    // a save from a copy a little old undid what the partner had changed
    // meanwhile: a place corrected on one phone took back the time set on
    // the other. The server is sent what this edit changed; it keeps the
    // rest as it is. The phone's copy, and an event the server has not
    // named yet, still take the whole event.
    final held = PlanEventDraft(
      title: event.title,
      date: event.date,
      slot: event.slot,
      exactTime: event.exactTime,
      placeLabel: event.placeLabel,
      responsibleName: event.responsibleName,
      note: event.note,
    ).toJson(isMain: event.isMain);
    final unsent = OfflineWrites.isLocalId(id);
    final changes = <String, dynamic>{
      for (final entry in payload.entries)
        if (unsent || entry.value != held[entry.key]) entry.key: entry.value,
    };
    if (!unsent && changes.isEmpty) return event;
    final cached =
        await _reads.cachedItem(OfflineTables.cachedPlanEvents, id) ??
        {'id': id, 'weddingPlanId': weddingPlanId, 'type': event.type.wire};
    final localJson = {...cached, ...payload, 'id': id};
    final json = await _writes.queued(
      entityType: 'plan_event',
      operation: 'update',
      method: 'PATCH',
      endpoint: '${_base(weddingPlanId)}/$id',
      payload: changes,
      table: OfflineTables.cachedPlanEvents,
      localJson: localJson,
      planId: weddingPlanId,
      localEntityId: id,
      replacePendingForEntity: true,
      pendingCreate: PendingCreate(
        endpoint: _base(weddingPlanId),
        payload: {'type': event.type.wire, ...payload},
      ),
    );
    await _putInCopy(weddingPlanId, json);
    return PlanEvent.fromJson(json);
  }

  Future<void> remove(String weddingPlanId, String eventId) async {
    await _writes.queued(
      entityType: 'plan_event',
      operation: 'delete',
      method: 'DELETE',
      endpoint: '${_base(weddingPlanId)}/$eventId',
      payload: const {},
      table: OfflineTables.cachedPlanEvents,
      localJson: {'id': eventId, 'weddingPlanId': weddingPlanId},
      planId: weddingPlanId,
      localEntityId: eventId,
      replacePendingForEntity: true,
    );
    await _dropFromCopy(weddingPlanId, eventId);
  }

  /// The copy the screens read (the whole view) gets the row too, so an
  /// event saved without the server shows at once.
  Future<void> _putInCopy(
    String weddingPlanId,
    Map<String, dynamic> row,
  ) async {
    final view = await _reads.cachedBlob(_key(weddingPlanId));
    if (view == null) return;
    // RA-MO-195: an event of one of the plan's kinds (all but «CUSTOM»)
    // is one per plan. Added offline it stayed in the copy's suggestions,
    // so it was offered and added again (the server refuses the second,
    // and it stuck the queue), and a wedding without its own row yet stood
    // beside the new one. The copy holds it once, and suggests it no more.
    final type = row['type']?.toString();
    final onePerPlan = type != null && type != PlanEventType.custom.wire;
    final items = [
      for (final item in view['items'] as List? ?? const [])
        if (item is Map &&
            item['id']?.toString() != row['id']?.toString() &&
            !(onePerPlan && item['type'] == type && item['id'] == null))
          Map<String, dynamic>.from(item),
      row,
    ];
    final suggestions = [
      for (final value in view['suggestions'] as List? ?? const [])
        if (!onePerPlan || value != type) value,
    ];
    await _reads.putBlob(_key(weddingPlanId), {
      ...view,
      'items': items,
      'suggestions': suggestions,
    });
  }

  Future<void> _dropFromCopy(String weddingPlanId, String eventId) async {
    final view = await _reads.cachedBlob(_key(weddingPlanId));
    if (view == null) return;
    final items = [
      for (final item in view['items'] as List? ?? const [])
        if (item is Map && item['id']?.toString() != eventId)
          Map<String, dynamic>.from(item),
    ];
    await _reads.putBlob(_key(weddingPlanId), {...view, 'items': items});
  }
}
