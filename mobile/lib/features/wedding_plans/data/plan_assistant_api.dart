import '../../../core/experience_v3/aarast_journey_profile.dart'
    show ReaderVoice;
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../models/plan_assistant.dart';

/// The planning assistant (V1 checklist 4.12). Online only: an answer needs
/// the model, so no question is queued and no answer is kept. The phone
/// keeps one thing, with [offline]: whether the assistant is open to this
/// plan's reader, so the home draws its door at once. The consent is the
/// server's record (RA-BE-161), never a flag the question carries.
class PlanAssistantApi {
  PlanAssistantApi(this._client, {OfflineSyncService? offline})
    : _reads = OfflineReads(_client, offline);

  final ApiClient _client;
  final OfflineReads _reads;

  late final _writes = OfflineWrites(_client, null);

  static String _statusKey(String weddingPlanId) =>
      'plan-assistant-status:$weddingPlanId';

  static const _reportReachesTeam = 'البلاغ يوصل فريق اعّرست، فيحتاج النت.';
  static const _consentIsKept = 'الموافقة تنحفظ عند اعّرست، فتحتاج النت.';

  static String _consentPath(String weddingPlanId) =>
      '/api/v1/wedding-plans/$weddingPlanId/assistant/consent';

  /// RA-BE-161: the consent is the account's record, read and taken back
  /// here without any plan.
  static const _accountConsentPath = '/api/v1/me/assistant/consent';
  static const _accountConsentKey = 'assistant-account-consent';

  /// RA-BE-161: w36 «شغّل المساعد» records the reader's consent on the
  /// server, with its date (a repeated agreement keeps the first).
  Future<DateTime> recordConsent(String weddingPlanId) async {
    final json = await _writes.serverOnly(
      reason: _consentIsKept,
      method: 'PUT',
      path: _consentPath(weddingPlanId),
    );
    final at = DateTime.tryParse(json['consentedAt']?.toString() ?? '');
    if (at == null) {
      throw ApiException(
        ReaderVoice.say(
          'ما انحفظت الموافقة. جرّب مرة ثانية.',
          'ما انحفظت الموافقة. جرّبي مرة ثانية.',
        ),
      );
    }
    return at;
  }

  /// RA-BE-161, w40: takes the account's consent back on the server; no
  /// plan is needed, so a reader who no longer reads one still can.
  Future<void> withdrawConsent() async {
    await _writes.serverOnly(
      reason: _consentIsKept,
      method: 'DELETE',
      path: _accountConsentPath,
    );
    await _reads.putBlob(_accountConsentKey, {'consentedAt': null});
  }

  /// RA-BE-161, w40: the account's consent and the daily limit, without
  /// any plan; offline, the phone's last copy.
  Future<({DateTime? consentedAt, int dailyLimit})> accountConsent() async {
    final json = await _reads.blob(
      _accountConsentPath,
      metaKey: _accountConsentKey,
    );
    final limit = json['dailyLimit'];
    return (
      consentedAt: DateTime.tryParse(json['consentedAt']?.toString() ?? ''),
      dailyLimit: limit is int ? limit : int.tryParse('$limit') ?? 0,
    );
  }

  /// The longest answer a report carries (the server's bound); a longer
  /// answer is cut to its start.
  static const reportAnswerMax = 20000;

  /// RA-ST-04 (D95): «بلّغ عن الإجابة». The assistant keeps no answer, so
  /// the report carries the one on screen, with what was asked and why, and
  /// the server's [answerId] that proves it is the assistant's (RA-BE-166).
  Future<void> reportAnswer(
    String weddingPlanId, {
    required String answerId,
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
        'answerId': answerId,
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

  /// The server's answer now (what is left today is only true fresh), kept
  /// on the phone for [knownStatus].
  Future<PlanAssistantStatus> status(String weddingPlanId) async {
    final json = await _client.getJson(
      '/api/v1/wedding-plans/$weddingPlanId/assistant',
    );
    await _reads.putBlob(_statusKey(weddingPlanId), json);
    return PlanAssistantStatus.fromJson(json);
  }

  /// The last answer kept on the phone, or null before the first one. Only
  /// for whether the door shows: its counts may be old.
  Future<PlanAssistantStatus?> knownStatus(String weddingPlanId) async {
    final json = await _reads.cachedBlob(_statusKey(weddingPlanId));
    return json == null ? null : PlanAssistantStatus.fromJson(json);
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
      },
      receiveTimeout: answerTimeout,
    );
    return PlanAssistantAnswer.fromJson(json);
  }
}
