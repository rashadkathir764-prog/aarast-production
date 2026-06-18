import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/debts/data/debt_installment_api.dart';
import 'package:aarast_mobile/features/debts/models/debt.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Debt.fromJson', () {
    test('treats a missing creditorPhone as null', () {
      final debt = Debt.fromJson(_debtJson()..remove('creditorPhone'));

      expect(debt.creditorPhone, isNull);
    });

    test('reads creditorPhone when present', () {
      final debt = Debt.fromJson(_debtJson(creditorPhone: '+967 777 123 456'));

      expect(debt.creditorPhone, '+967 777 123 456');
    });

    test('handles a null creditorPhone', () {
      final debt = Debt.fromJson(_debtJson());

      expect(debt.creditorPhone, isNull);
    });
  });

  group('DebtInstallmentApi.createDebt', () {
    test('normalizes creditorPhone when provided', () async {
      final apiClient = ApiClient(tokenProvider: () async => 'token');
      Map<String, dynamic>? capturedPayload;
      apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedPayload = Map<String, dynamic>.from(options.data as Map);
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 201,
                data: _debtJson(creditorPhone: '+967777123456'),
              ),
            );
          },
        ),
      );
      final api = DebtInstallmentApi(apiClient);

      final debt = await api.createDebt(
        weddingPlanId: 'plan-1',
        creditorName: 'Vendor',
        creditorPhone: '  +967 777 123 456  ',
        title: 'Hall balance',
        totalAmount: '1000',
      );

      expect(capturedPayload?['creditorPhone'], '+967777123456');
      expect(debt.creditorPhone, '+967777123456');
    });

    test('omits a blank creditorPhone', () async {
      final apiClient = ApiClient(tokenProvider: () async => 'token');
      Map<String, dynamic>? capturedPayload;
      apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedPayload = Map<String, dynamic>.from(options.data as Map);
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 201,
                data: _debtJson(),
              ),
            );
          },
        ),
      );
      final api = DebtInstallmentApi(apiClient);

      final debt = await api.createDebt(
        weddingPlanId: 'plan-1',
        creditorName: 'Vendor',
        creditorPhone: '   ',
        title: 'Hall balance',
        totalAmount: '1000',
      );

      expect(capturedPayload, isNot(contains('creditorPhone')));
      expect(debt.creditorPhone, isNull);
    });

    test('normalizes creditorPhone in offline cache and queue', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final database = JsonLocalDatabase(preferences);
      await database.initialize();
      final apiClient = ApiClient(tokenProvider: () async => 'token');
      apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'offline',
              ),
            );
          },
        ),
      );
      final offline = OfflineSyncService(
        database: database,
        apiClient: apiClient,
      );
      final api = DebtInstallmentApi(apiClient, offline: offline);

      final debt = await api.createDebt(
        weddingPlanId: 'plan-1',
        creditorName: 'Vendor',
        creditorPhone: '  0777 123 456  ',
        title: 'Hall balance',
        totalAmount: '1000',
      );

      final cached = await database.readCachedItem(
        table: OfflineTables.cachedDebts,
        id: debt.id,
      );
      final queued = await database.pendingSyncItems();
      expect(debt.creditorPhone, '+967777123456');
      expect(cached?['creditorPhone'], '+967777123456');
      expect(queued.single.payload['creditorPhone'], '+967777123456');
    });
  });
}

Map<String, dynamic> _debtJson({String? creditorPhone}) {
  return {
    'id': 'debt-1',
    'weddingPlanId': 'plan-1',
    'creditorName': 'Vendor',
    'creditorPhone': creditorPhone,
    'title': 'Hall balance',
    'totalAmount': '1000',
    'paidAmount': '0',
    'status': 'OPEN',
    'createdAt': '2026-06-18T00:00:00.000Z',
    'updatedAt': '2026-06-18T00:00:00.000Z',
  };
}
