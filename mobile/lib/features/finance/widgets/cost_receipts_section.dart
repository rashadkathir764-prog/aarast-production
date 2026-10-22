import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/cost_receipts_api.dart';
import '../models/cost_receipt.dart';
import 'receipt_flows.dart';

/// The receipt photos kept with a cost (V1 checklist 4.4). They need a
/// connection: each photo is private and opened through a short-lived link,
/// so the list is loaded when the section appears and after each change.
class CostReceiptsSection extends StatefulWidget {
  const CostReceiptsSection({
    required this.costId,
    required this.canManage,
    this.costPaymentId,
    this.api,
    super.key,
  });

  final String costId;
  final bool canManage;

  /// One payment's receipts: only these are shown, and new ones are kept
  /// with that payment. Null shows every receipt of the cost.
  final String? costPaymentId;

  /// Defaults to one over the app's [ApiClient]; tests pass a fake.
  final CostReceiptsApi? api;

  @override
  State<CostReceiptsSection> createState() => _CostReceiptsSectionState();
}

class _CostReceiptsSectionState extends State<CostReceiptsSection> {
  List<CostReceipt> _receipts = const [];

  /// Every receipt of the cost: the limit of 10 is per cost.
  int _costReceiptCount = 0;
  bool _available = true;
  bool _loading = true;
  bool _busy = false;
  bool _failed = false;

  late CostReceiptsApi _api;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final injected = widget.api;
    if (injected != null) {
      _api = injected;
    } else {
      try {
        _api = CostReceiptsApi(context.read<ApiClient>());
      } on ProviderNotFoundException {
        setState(() => _available = false);
        return;
      }
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final receipts = await _api.list(widget.costId);
      final paymentId = widget.costPaymentId;
      if (mounted) {
        setState(() {
          _costReceiptCount = receipts.length;
          _receipts = paymentId == null
              ? receipts
              : receipts
                    .where((receipt) => receipt.costPaymentId == paymentId)
                    .toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Runs one network change with the section busy, then reloads it.
  /// Questions are asked before, so nothing spins behind a dialog.
  Future<void> _busyWhile(Future<bool> Function() action) async {
    setState(() => _busy = true);
    try {
      if (await action()) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add({CostReceipt? replacing}) async {
    final file = await pickReceiptImage(context);
    if (file == null || !mounted) return;
    await _busyWhile(
      () => saveReceiptImage(
        context,
        _api,
        file,
        costId: widget.costId,
        costPaymentId: replacing?.costPaymentId ?? widget.costPaymentId,
        replacing: replacing,
      ),
    );
  }

  Future<void> _open(CostReceipt receipt) async {
    final action = await showReceiptViewer(
      context,
      receipt,
      canManage: widget.canManage,
    );
    if (!mounted) return;
    switch (action) {
      case ReceiptViewerAction.remove:
        if (!await confirmRemoveReceipt(context) || !mounted) return;
        await _busyWhile(() => deleteReceipt(context, _api, receipt));
      case ReceiptViewerAction.replace:
        await _add(replacing: receipt);
      case null:
        // The link lasts two minutes: refresh so the next opening works.
        await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final forPayment = widget.costPaymentId != null;
    final canAdd = widget.canManage && !_busy && _costReceiptCount < 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionTitle(
          forPayment ? 'الإيصال' : 'الإيصالات',
          action: canAdd && _receipts.isNotEmpty ? 'أضف إيصال' : null,
          onAction: canAdd && _receipts.isNotEmpty ? _add : null,
        ),
        if (_loading || _busy)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: AarastInlineSpinner(color: AarastV3Color.primary),
            ),
          )
        else if (_failed)
          JourneyListState(
            phase: JourneyListPhase.error,
            section: JourneySection.money,
            onRetry: _load,
          )
        else if (_receipts.isEmpty)
          _MissingReceipt(forPayment: forPayment, onAdd: canAdd ? _add : null)
        else ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final receipt in _receipts)
                ReceiptThumb(
                  key: Key('cost-receipt-${receipt.id}'),
                  receipt: receipt,
                  onTap: () => _open(receipt),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ما يشوفها إلا اللي يشوف هذا الاتفاق',
            style: JourneyType.of(
              JourneyType.caption,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// No receipt yet: the empty frame, which takes a photo for a manager.
class _MissingReceipt extends StatelessWidget {
  const _MissingReceipt({required this.forPayment, required this.onAdd});

  final bool forPayment;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ReceiptThumb(
          key: const ValueKey('cost-receipt-add'),
          receipt: null,
          onTap: onAdd,
          size: 72,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            onAdd == null
                ? 'ما في إيصال محفوظ'
                : forPayment
                ? 'صوّر إيصال هذي الدفعة واحفظه معها'
                : 'صوّر إيصالات الدفع واحفظها مع الاتفاق',
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
