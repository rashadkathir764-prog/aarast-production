import '../../../core/network/api_client.dart';
import '../models/plan_assistant.dart';

/// The planning assistant (V1 checklist 4.12). Online only: an answer needs
/// the model, so nothing is queued or cached.
class PlanAssistantApi {
  PlanAssistantApi(this._client);

  final ApiClient _client;

  /// The model may think for a while; the server gives up first.
  static const answerTimeout = Duration(seconds: 100);

  Future<PlanAssistantStatus> status(String weddingPlanId) async {
    final json = await _client.getJson(
      '/api/v1/wedding-plans/$weddingPlanId/assistant',
    );
    return PlanAssistantStatus.fromJson(json);
  }

  Future<PlanAssistantAnswer> ask(
    String weddingPlanId, {
    required PlanAssistantKind kind,
    String? question,
  }) async {
    final text = question?.trim();
    final json = await _client.postJsonWithReceiveTimeout(
      '/api/v1/wedding-plans/$weddingPlanId/assistant/questions',
      {
        'kind': kind.apiValue,
        if (text != null && text.isNotEmpty) 'question': text,
        // The screen asks for consent before the first question.
        'consent': true,
      },
      receiveTimeout: answerTimeout,
    );
    return PlanAssistantAnswer.fromJson(json);
  }
}
