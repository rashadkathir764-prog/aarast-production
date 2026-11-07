import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../models/plan_assistant.dart';

/// The planning assistant (V1 checklist 4.12). Online only: an answer needs
/// the model, so nothing is queued or cached.
class PlanAssistantApi {
  PlanAssistantApi(this._client);

  final ApiClient _client;

  late final _writes = OfflineWrites(_client, null);

  static const _reportReachesTeam = 'البلاغ يوصل فريق اعّرست، فيحتاج الخادم.';

  /// The longest answer a report carries (the server's bound); a longer
  /// answer is cut to its start.
  static const reportAnswerMax = 20000;

  /// RA-ST-04 (D95): «بلّغ عن الإجابة». The assistant keeps no answer, so
  /// the report carries the one on screen, with what was asked and why.
  Future<void> reportAnswer(
    String weddingPlanId, {
    required PlanAssistantKind kind,
    required String? question,
    required String answer,
    required String reason,
  }) async {
    final text = question?.trim();
    await _writes.serverOnly(
      reason: _reportReachesTeam,
      method: 'POST',
      path: '/api/v1/wedding-plans/$weddingPlanId/assistant/reports',
      body: {
        'kind': kind.apiValue,
        if (text != null && text.isNotEmpty) 'question': text,
        'answer': answer.length > reportAnswerMax
            ? answer.substring(0, reportAnswerMax)
            : answer,
        'reason': reason,
      },
    );
  }

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
