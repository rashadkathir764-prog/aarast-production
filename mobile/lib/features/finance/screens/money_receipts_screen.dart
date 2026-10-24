import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/cost_receipts_api.dart';
import '../data/finance_local_data_source.dart';
import '../models/cost_receipt.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/receipt_flows.dart';

// w22 «الإيصالات»: every payment that counts, with its receipt or the empty
// frame asking for one, and how many have one. Coverage is counted here from
// one receipts call per agreement (the server has no plan-wide list).

class MoneyReceiptsScreen extends StatefulWidget {
  const MoneyReceiptsScreen({required this.weddingPlanId, this.api, super.key});

  final String weddingPlanId;

  /// Defaults to one over the app's [ApiClient]; tests pass a fake.
  final CostReceiptsApi? api;

  @override
  State<MoneyReceiptsScreen> createState() => _MoneyReceiptsScreenState();
}

class _MoneyReceiptsScreenState extends State<MoneyReceiptsScreen> {
  /// More pages than this is not a wedding's payments: stop asking.
  static const _maxPaymentPages = 20;

  late final CostReceiptsApi _api =
      widget.api ?? CostReceiptsApi(context.read<ApiClient>());
  Map<String, List<CostReceipt>> _receiptsByCost = const {};
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refreshMoney = false}) async {
    final provider = context.read<FinanceProvider>();
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (refreshMoney || provider.loadedPlanId != widget.weddingPlanId) {
        await provider.loadMoney(widget.weddingPlanId);
      }
      for (
        var page = 0;
        page < _maxPaymentPages && provider.hasMorePayments;
        page++
      ) {
        await provider.loadMorePayments();
      }
      final costIds = {
        for (final payment in _counted(provider.payments)) payment.costId,
      };
      final lists = await Future.wait([
        for (final costId in costIds) _api.list(costId),
      ]);
      if (!mounted) return;
      setState(() {
        _receiptsByCost = {
          for (final (index, costId) in costIds.indexed) costId: lists[index],
        };
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static List<CostPayment> _counted(List<CostPayment> payments) =>
      payments
          .where((payment) => !payment.isReversal && !payment.isReversed)
          .toList()
        ..sort((a, b) => b.paidAt.compareTo(a.paidAt));

  CostReceipt? _receiptOf(CostPayment payment) {
    for (final receipt in _receiptsByCost[payment.costId] ?? const []) {
      if (receipt.costPaymentId == payment.id) return receipt;
    }
    return null;
  }

  /// Runs one network change busy, then reloads; questions come before.
  Future<void> _busyWhile(Future<bool> Function() action) async {
    setState(() => _busy = true);
    try {
      if (await action() && mounted) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add({
    required String costId,
    String? costPaymentId,
    CostReceipt? replacing,
  }) async {
    final file = await pickReceiptImage(context);
    if (file == null || !mounted) return;
    await _busyWhile(
      () => saveReceiptImage(
        context,
        _api,
        file,
        costId: costId,
        costPaymentId: costPaymentId,
        replacing: replacing,
      ),
    );
  }

  Future<void> _open(CostReceipt receipt, bool canManage) async {
    final action = await showReceiptViewer(
      context,
      receipt,
      canManage: canManage,
    );
    if (!mounted) return;
    switch (action) {
      case ReceiptViewerAction.remove:
        if (!await confirmRemoveReceipt(context) || !mounted) return;
        await _busyWhile(() => deleteReceipt(context, _api, receipt));
      case ReceiptViewerAction.replace:
        await _add(
          costId: receipt.weddingCostId,
          costPaymentId: receipt.costPaymentId,
          replacing: receipt,
        );
      case null:
        // The link lasts two minutes: refresh so the next opening works.
        await _load();
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.money(widget.weddingPlanId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final canManage = provider.canManageMoney;
    final payments = _counted(provider.payments);
    final covered = payments.where((p) => _receiptOf(p) != null).length;
    final costReceipts = [
      for (final list in _receiptsByCost.values)
        for (final receipt in list)
          if (receipt.costPaymentId == null) receipt,
    ];

    final Widget body;
    if (FinanceLocalDataSource.isLocalGuestPlanId(widget.weddingPlanId)) {
      body = JourneyListState(
        phase: JourneyListPhase.empty,
        section: JourneySection.money,
        emptyIcon: LucideIcons.receipt,
        emptyTitle: context.say(
          'الإيصالات تنحفظ مع حسابك، سجّل دخولك أول',
          'الإيصالات تنحفظ مع حسابك، سجّلي دخولك أول',
        ),
      );
    } else if (_loading && _receiptsByCost.isEmpty) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.money,
      );
    } else if (_failed && _receiptsByCost.isEmpty) {
      body = JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.money,
        onRetry: () => _load(refreshMoney: true),
      );
    } else if (payments.isEmpty && costReceipts.isEmpty) {
      body = JourneyListState(
        phase: JourneyListPhase.empty,
        section: JourneySection.money,
        emptyIcon: LucideIcons.receipt,
        emptyTitle: context.say('ما سجلت دفعات بعد', 'ما سجلتِ دفعات بعد'),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_failed) ...[
            JourneyListNotice(
              offline: false,
              onRetry: () => _load(refreshMoney: true),
            ),
            const SizedBox(height: 12),
          ],
          if (_busy)
            const AarastV3ProgressLine(
              height: 3,
              semanticsLabel: 'يحفظ الإيصال',
            ),
          _ReceiptGrid(
            tiles: [
              for (final payment in payments)
                _tile(provider, payment, _receiptOf(payment), canManage),
            ],
          ),
          if (costReceipts.isNotEmpty) ...[
            const SizedBox(height: 8),
            const JourneySectionTitle('للاتفاق كله'),
            _ReceiptGrid(
              tiles: [
                for (final receipt in costReceipts)
                  _ReceiptTile(
                    key: Key('receipts-cost-${receipt.id}'),
                    title: _costName(provider, receipt.weddingCostId),
                    line: formatArabicDayMonth(receipt.createdAt),
                    receipt: receipt,
                    onTap: () => _open(receipt, canManage),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          JourneyNote(
            text: canManage
                ? context.say(
                    'افتح أي إيصال تبدله أو تشيله. الدفعة تبقى حتى لو شلت الإيصال.',
                    'افتحي أي إيصال تبدلينه أو تشيلينه. الدفعة تبقى حتى لو شلتِ الإيصال.',
                  )
                : context.say(
                    'تقدر تشوف الإيصالات، والإضافة لمدير المال.',
                    'تقدرين تشوفين الإيصالات، والإضافة لمدير المال.',
                  ),
          ),
        ],
      );
    }

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: JourneySubHeader(
              title: 'الإيصالات',
              subtitle: payments.isEmpty || _receiptsByCost.isEmpty
                  ? null
                  : '$covered من ${payments.length} دفعة لها إيصال',
              onBack: _goBack,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: context.accent.primary,
              onRefresh: () => _load(refreshMoney: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [body],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _costName(FinanceProvider provider, String costId) {
    final cost = provider.costById(costId);
    return cost?.partyLabel ?? cost?.title ?? 'اتفاق';
  }

  Widget _tile(
    FinanceProvider provider,
    CostPayment payment,
    CostReceipt? receipt,
    bool canManage,
  ) {
    final currency = provider.summary.currency;
    final amount = provider.amountsHidden
        ? '••••'
        : compactMoneyParts(
            moneyValue(payment.amount),
            currencyCode: currency,
          ).plainText;
    final cost = provider.costById(payment.costId);
    return _ReceiptTile(
      key: Key('receipts-payment-${payment.id}'),
      title: cost?.partyLabel ?? cost?.title ?? payment.costTitle ?? 'دفعة',
      line: receipt == null
          ? '$amount · بدون إيصال'
          : '$amount · ${formatArabicDayMonth(payment.paidAt)}',
      receipt: receipt,
      onTap: receipt != null
          ? () => _open(receipt, canManage)
          : canManage && !_busy
          ? () => _add(costId: payment.costId, costPaymentId: payment.id)
          : null,
    );
  }
}

/// Two tiles a row, each as tall as its words need at large text.
class _ReceiptGrid extends StatelessWidget {
  const _ReceiptGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({
    required this.title,
    required this.line,
    required this.receipt,
    required this.onTap,
    super.key,
  });

  final String title;
  final String line;
  final CostReceipt? receipt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final missing = receipt == null;
    final content = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: missing ? AarastV3Color.canvas : AarastV3Color.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: missing ? AarastV3Color.line : AarastV3Color.paper,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) => ReceiptThumb(
              receipt: receipt,
              onTap: null,
              width: constraints.maxWidth,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: JourneyType.of(
              JourneyType.body,
              weight: JourneyType.bold,
              color: missing ? AarastV3Color.textMuted : AarastV3Color.ink,
            ),
          ),
          Text(
            line,
            style: JourneyType.of(
              JourneyType.caption,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: '$title، $line',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(onTap: onTap!, child: content),
    );
  }
}
