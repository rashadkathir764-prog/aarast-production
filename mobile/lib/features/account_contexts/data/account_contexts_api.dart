import '../../../core/network/api_client.dart';
import '../models/account_context.dart';

abstract interface class AccountContextsGateway {
  Future<List<AccountContext>> listContexts();

  Future<AccountContext> validateContext(String contextKey);
}

class AccountContextsApi implements AccountContextsGateway {
  const AccountContextsApi(this._apiClient);

  static final RegExp _contextKeyPattern = RegExp(
    r'^(?:plan:[^:]{1,128}:(?:owner|contributor)|provider:[^:]{1,128})$',
  );

  final ApiClient _apiClient;

  @override
  Future<List<AccountContext>> listContexts() async {
    final payload = await _apiClient.getJsonList('/api/v1/contexts');
    return payload
        .map((item) {
          if (item is! Map) {
            throw const FormatException(
              'Account contexts response must contain JSON objects',
            );
          }
          return AccountContext.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
  }

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    if (!_contextKeyPattern.hasMatch(contextKey)) {
      throw ArgumentError.value(
        contextKey,
        'contextKey',
        'must be a canonical account context key',
      );
    }
    final payload = await _apiClient.postJson('/api/v1/contexts/validate', {
      'contextKey': contextKey,
    });
    final context = AccountContext.fromJson(payload);
    if (context.contextKey != contextKey) {
      throw const FormatException(
        'Validated account context does not match the requested context key',
      );
    }
    return context;
  }
}
