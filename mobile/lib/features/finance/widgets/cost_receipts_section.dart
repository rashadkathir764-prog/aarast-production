import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/cost_receipts_api.dart';
import '../models/cost_receipt.dart';

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
  String? _error;

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
      _error = null;
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
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل الإيصالات.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final source = await showAarastBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('تصوير الإيصال'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('اختيار من المعرض'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 2000,
    );
    if (file == null || !mounted) return;
    final uploader = context.read<MediaUploadApi>();
    setState(() => _busy = true);
    try {
      final ticket = await uploader.uploadImage(file: file, purpose: 'cost-receipt');
      await _api.add(
        widget.costId,
        attachmentRef: ticket.attachmentRef,
        costPaymentId: widget.costPaymentId,
      );
      if (mounted) AarastToast.showSuccess(context, 'حُفظ الإيصال.');
      await _load();
    } on ApiException catch (error) {
      if (mounted) {
        AarastToast.showError(
          context,
          costReceiptErrorMessage(error.serverCode) ?? error.message,
        );
      }
    } catch (_) {
      if (mounted) AarastToast.showError(context, 'تعذر حفظ الإيصال الآن.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(CostReceipt receipt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: const Text('حذف الإيصال؟'),
        content: const Text('تُحذف الصورة نهائيًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _api.delete(widget.costId, receipt.id);
      await _load();
    } on ApiException catch (error) {
      if (mounted) AarastToast.showError(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(CostReceipt receipt) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: const Text('الإيصال'),
        scrollable: false,
        content: InteractiveViewer(
          child: Image.network(
            receipt.downloadUrl,
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('انتهت صلاحية الرابط. أغلق وافتح الإيصال مرة أخرى.'),
            ),
          ),
        ),
        actions: [
          if (widget.canManage)
            TextButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _delete(receipt);
              },
              icon: const Icon(LucideIcons.trash2, color: AppTheme.danger),
              label: const Text('حذف', style: TextStyle(color: AppTheme.danger)),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
    // The link lasts two minutes: refresh so the next opening works.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final forPayment = widget.costPaymentId != null;
    final canAdd = widget.canManage && !_busy && _costReceiptCount < 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: forPayment ? 'إيصال الدفعة' : 'الإيصالات',
          subtitle: _receipts.isEmpty
              ? (forPayment
                    ? 'صوّر إيصال هذه الدفعة واحفظه معها.'
                    : 'صوّر إيصال الدفع واحفظه مع التكلفة.')
              : '${_receipts.length} إيصال محفوظ، لا يراه إلا من يرى هذه التكلفة.',
          icon: LucideIcons.receipt,
          actionLabel: canAdd ? 'إضافة إيصال' : null,
          onAction: canAdd ? _add : null,
        ),
        const SizedBox(height: 10),
        if (_loading || _busy)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: AarastInlineSpinner()),
          )
        else if (_error != null)
          AarastErrorState(
            title: 'تعذر تحميل الإيصالات',
            message: _error!,
            onRetry: _load,
          )
        else if (_receipts.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final receipt in _receipts)
                InkWell(
                  key: Key('cost-receipt-${receipt.id}'),
                  onTap: () => _open(receipt),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      receipt.downloadUrl,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 84,
                        height: 84,
                        color: AppTheme.surfaceRaised,
                        child: const Icon(LucideIcons.receipt),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
