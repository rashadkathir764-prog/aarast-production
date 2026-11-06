import 'dart:typed_data';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/api_contract.dart';
import 'package:aarast_mobile/core/widgets/app_update_gate.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// D93 (RA-BE-01): the app says which contract it was built for, and a
/// server that no longer serves it is answered with «حدّث التطبيق».
void main() {
  tearDown(() => appUpdateRequired.value = false);

  test('every request carries the app\'s contract number', () async {
    final adapter = _Adapter(200, '{"ok":true}');
    final client = ApiClient(tokenProvider: () async => 'token')
      ..dio.httpClientAdapter = adapter;

    await client.getJson('/api/v1/wedding-plans');
    await client.postJson('/api/v1/wedding-plans/plan-1/tasks', const {});

    expect(adapter.contracts, ['$apiContractVersion', '$apiContractVersion']);
  });

  test('426 APP_UPDATE_REQUIRED raises the update gate', () async {
    final client = ApiClient(tokenProvider: () async => 'token')
      ..dio.httpClientAdapter = _Adapter(
        426,
        '{"statusCode":426,"code":"APP_UPDATE_REQUIRED",'
        '"message":"نسخة التطبيق قديمة. حدّثه من المتجر عشان تكمل."}',
      );

    await expectLater(
      client.getJson('/api/v1/wedding-plans'),
      throwsA(isA<ApiException>()),
    );
    expect(appUpdateRequired.value, isTrue);
  });

  test('another 4xx leaves the gate down', () async {
    final client = ApiClient(tokenProvider: () async => 'token')
      ..dio.httpClientAdapter = _Adapter(400, '{"message":"bad"}');

    await expectLater(
      client.getJson('/api/v1/wedding-plans'),
      throwsA(isA<ApiException>()),
    );
    expect(appUpdateRequired.value, isFalse);
  });

  testWidgets('the gate stands over the app once raised', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppUpdateGate(child: Text('the app'))),
    );
    expect(find.text('the app'), findsOneWidget);

    appUpdateRequired.value = true;
    await tester.pump();
    expect(find.text('the app'), findsNothing);
    expect(find.text('حدّث اعّرست'), findsOneWidget);
    expect(find.byKey(const Key('app-update-open-store')), findsOneWidget);
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final String body;
  final List<String?> contracts = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    contracts.add(options.headers[apiContractHeader]?.toString());
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
