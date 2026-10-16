import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/data/cost_receipts_api.dart';
import 'package:aarast_mobile/features/finance/models/cost_receipt.dart';
import 'package:aarast_mobile/features/finance/widgets/cost_receipts_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// V1 checklist 4.4: receipt photos kept with a cost.

class _ReceiptsApiFake extends CostReceiptsApi {
  _ReceiptsApiFake(this.receipts)
    : super(ApiClient(tokenProvider: () async => null));

  List<CostReceipt> receipts;
  final deleted = <String>[];

  @override
  Future<List<CostReceipt>> list(String costId) async => receipts;

  @override
  Future<void> delete(String costId, String receiptId) async {
    deleted.add(receiptId);
    receipts = receipts.where((item) => item.id != receiptId).toList();
  }
}

CostReceipt _receipt(String id, {String? paymentId}) => CostReceipt.fromJson({
  'id': id,
  'weddingCostId': 'cost-1',
  'costPaymentId': ?paymentId,
  'downloadUrl': 'https://media.invalid/$id.png',
  'createdAt': '2026-10-16T09:00:00Z',
});

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  test('a receipt reads its signed link and the server codes read as actions', () {
    final receipt = _receipt('r1');
    expect(receipt.downloadUrl, 'https://media.invalid/r1.png');
    expect(receipt.costPaymentId, isNull);
    expect(costReceiptErrorMessage('COST_RECEIPT_LIMIT'), contains('10 إيصالات'));
    expect(costReceiptErrorMessage('COST_HAS_RECEIPTS'), contains('احذفها أولًا'));
    expect(costReceiptErrorMessage('OTHER'), isNull);
  });

  testWidgets('the section lists receipts and offers to add one', (tester) async {
    final api = _ReceiptsApiFake([_receipt('r1'), _receipt('r2')]);
    await tester.pumpWidget(
      _host(CostReceiptsSection(costId: 'cost-1', canManage: true, api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cost-receipt-r1')), findsOneWidget);
    expect(find.byKey(const Key('cost-receipt-r2')), findsOneWidget);
    expect(find.textContaining('2 إيصال محفوظ'), findsOneWidget);
    expect(find.text('إضافة إيصال'), findsOneWidget);
  });

  testWidgets('a reader without money rights sees receipts but cannot add', (tester) async {
    final api = _ReceiptsApiFake([_receipt('r1')]);
    await tester.pumpWidget(
      _host(CostReceiptsSection(costId: 'cost-1', canManage: false, api: api)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cost-receipt-r1')), findsOneWidget);
    expect(find.text('إضافة إيصال'), findsNothing);
  });

  testWidgets('deleting from the opened receipt removes it', (tester) async {
    final api = _ReceiptsApiFake([_receipt('r1')]);
    await tester.pumpWidget(
      _host(CostReceiptsSection(costId: 'cost-1', canManage: true, api: api)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cost-receipt-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حذف'));
    await tester.pumpAndSettle();

    expect(api.deleted, ['r1']);
    expect(find.byKey(const Key('cost-receipt-r1')), findsNothing);
  });

  testWidgets('a payment shows only its own receipts; the limit counts the cost', (
    tester,
  ) async {
    final api = _ReceiptsApiFake([
      _receipt('r1', paymentId: 'pay-1'),
      _receipt('r2', paymentId: 'pay-2'),
      _receipt('r3'),
    ]);
    await tester.pumpWidget(
      _host(
        CostReceiptsSection(
          costId: 'cost-1',
          costPaymentId: 'pay-1',
          canManage: true,
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('إيصال الدفعة'), findsOneWidget);
    expect(find.byKey(const Key('cost-receipt-r1')), findsOneWidget);
    expect(find.byKey(const Key('cost-receipt-r2')), findsNothing);
    expect(find.byKey(const Key('cost-receipt-r3')), findsNothing);
    expect(find.text('إضافة إيصال'), findsOneWidget);

    // Ten receipts on the cost, none on this payment: no room left.
    api.receipts = [for (var i = 0; i < 10; i++) _receipt('c$i')];
    await tester.pumpWidget(
      _host(
        CostReceiptsSection(
          key: const ValueKey('full'),
          costId: 'cost-1',
          costPaymentId: 'pay-1',
          canManage: true,
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('إضافة إيصال'), findsNothing);
  });

  testWidgets('without an API client the section stays out of the way', (tester) async {
    await tester.pumpWidget(
      _host(const CostReceiptsSection(costId: 'cost-1', canManage: true)),
    );
    await tester.pumpAndSettle();
    expect(find.text('الإيصالات'), findsNothing);
  });
}
