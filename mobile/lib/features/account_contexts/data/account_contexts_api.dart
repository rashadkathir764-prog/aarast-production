import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../models/account_context.dart';

abstract interface class AccountContextsGateway {
  Future<List<AccountContext>> listContexts();
  Future<AccountContext> validateContext(String contextKey);
}

/// The account's contexts (its plans and its provider).
///
/// D85: the list is the phone's copy when the server is out of reach, so
/// the app opens on the last known plan; validating a context is the
/// server's say and waits for it.
class AccountContextsApi implements AccountContextsGateway {
  AccountContextsApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _reads = OfflineReads(apiClient, offline),
      _writes = OfflineWrites(apiClient, offline);

  static final RegExp _contextKeyPattern = RegExp(
    r'^(?:plan:[^:]{1,128}:(?:owner|contributor)|provider:[^:]{1,128})$',
  );

  static const _listKey = 'account-contexts';

  final OfflineReads _reads;
  final OfflineWrites _writes;

  @override
  Future<List<AccountContext>> listContexts() async {
    final payload = await _reads.blobList('/api/v1/contexts', metaKey: _listKey);
    return payload
        .map(AccountContext.fromJson)
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
    final payload = await _writes.serverOnly(
      reason: 'التحقق من السياق عند الخادم.',
      method: 'POST',
      path: '/api/v1/contexts/validate',
      body: {'contextKey': contextKey},
    );
    final context = AccountContext.fromJson(payload);
    if (context.contextKey != contextKey) {
      throw const FormatException(
        'Validated account context does not match the requested context key',
      );
    }
    return context;
  }
}
