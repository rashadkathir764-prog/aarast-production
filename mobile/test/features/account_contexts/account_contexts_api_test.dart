import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_context_test_data.dart';

void main() {
  test('listContexts uses the canonical protected endpoint', () async {
    late RequestOptions captured;
    final api = AccountContextsApi(
      _client((options) {
        captured = options;
        return [
          accountContextJson(role: AccountContextRole.owner),
          accountContextJson(
            role: AccountContextRole.contributor,
            planId: 'p2',
          ),
          accountContextJson(role: AccountContextRole.provider),
        ];
      }),
    );

    final contexts = await api.listContexts();

    expect(captured.method, 'GET');
    expect(captured.path, '/api/v1/contexts');
    expect(contexts.map((item) => item.role), [
      AccountContextRole.owner,
      AccountContextRole.contributor,
      AccountContextRole.provider,
    ]);
  });

  test(
    'validateContext posts contextKey and no client authority fields',
    () async {
      late RequestOptions captured;
      final api = AccountContextsApi(
        _client((options) {
          captured = options;
          return accountContextJson(
            role: AccountContextRole.contributor,
            planId: 'plan-2',
          );
        }),
      );

      final context = await api.validateContext('plan:plan-2:contributor');

      expect(captured.method, 'POST');
      expect(captured.path, '/api/v1/contexts/validate');
      expect(captured.data, {'contextKey': 'plan:plan-2:contributor'});
      expect(context.contextKey, 'plan:plan-2:contributor');
    },
  );

  test(
    'validateContext rejects blank, padded, and mismatched responses',
    () async {
      final api = AccountContextsApi(
        _client(
          (_) => accountContextJson(
            role: AccountContextRole.owner,
            planId: 'different-plan',
          ),
        ),
      );

      await expectLater(api.validateContext(''), throwsArgumentError);
      await expectLater(
        api.validateContext(' plan:plan-1:owner'),
        throwsArgumentError,
      );
      await expectLater(
        api.validateContext('plan:plan-1:owner'),
        throwsFormatException,
      );
    },
  );
}

ApiClient _client(Object? Function(RequestOptions options) responder) {
  final client = ApiClient(tokenProvider: () async => 'token');
  client.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: responder(options),
          ),
        );
      },
    ),
  );
  return client;
}
