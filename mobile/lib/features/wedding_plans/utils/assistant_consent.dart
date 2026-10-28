import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../data/plan_assistant_api.dart';

/// The planning assistant's consent on this phone (V1 checklist 4.12): the
/// assistant asks once before its first question sends the plan to the
/// model. w40 «المساعد الذكي» shows it and takes it back (D63); taken back,
/// the assistant asks again before the next question.
abstract final class AssistantConsent {
  static String _key(String? userId) =>
      'aarast.assistant.consent.v1.${userId ?? 'device'}';

  static Future<bool> isGiven(String? userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_key(userId)) == true;
  }

  static Future<void> set(String? userId, bool given) async {
    final preferences = await SharedPreferences.getInstance();
    if (given) {
      await preferences.setBool(_key(userId), true);
    } else {
      await preferences.remove(_key(userId));
    }
  }

  /// The questions a day the assistant answers for this plan's reader, or
  /// null when the assistant is not open to them.
  static Future<int?> dailyLimit(ApiClient client, String weddingPlanId) async {
    final status = await PlanAssistantApi(client).status(weddingPlanId);
    return status.enabled && status.allowed ? status.dailyLimit : null;
  }
}
