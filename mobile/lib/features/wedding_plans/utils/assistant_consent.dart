import '../../../core/network/api_client.dart';
import '../data/plan_assistant_api.dart';
import '../models/plan_assistant.dart';

/// The planning assistant's consent (V1 checklist 4.12), as the server keeps
/// it (RA-BE-161): the assistant asks once before its first question sends
/// the plan to the model, and the record is the account's, with its date.
/// w40 «المساعد الذكي» shows it and takes it back (D63); taken back, the
/// assistant asks again before the next question.
abstract final class AssistantConsent {
  /// The assistant for this plan's reader, or null when it is not open to
  /// them: its daily limit and the stored consent.
  static Future<PlanAssistantStatus?> read(
    ApiClient client,
    String weddingPlanId,
  ) async {
    final status = await PlanAssistantApi(client).status(weddingPlanId);
    return status.available ? status : null;
  }

  /// Records or takes back the consent on the server; returns what it holds.
  static Future<bool> set(
    ApiClient client,
    String weddingPlanId,
    bool given,
  ) async {
    final api = PlanAssistantApi(client);
    if (given) {
      await api.recordConsent(weddingPlanId);
    } else {
      await api.withdrawConsent(weddingPlanId);
    }
    return given;
  }
}
