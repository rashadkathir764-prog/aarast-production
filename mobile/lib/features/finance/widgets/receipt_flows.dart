import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/cost_receipts_api.dart';
import '../models/cost_receipt.dart';

/// What a money manager chose on an opened receipt.
enum ReceiptViewerAction { replace, remove }

/// Asks for a receipt photo, from the camera or the gallery. Null when the
/// person backs out.
Future<XFile?> pickReceiptImage(BuildContext context) async {
  final source = await showJourneySheet<ImageSource>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      title: null,
      children: [
        JourneyBox(
          padding: EdgeInsets.zero,
          child: JourneyList(
            children: [
              JourneyListRow(
                key: const ValueKey('receipt-source-camera'),
                icon: LucideIcons.camera,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
                title: context.say('صوّر الإيصال', 'صوّري الإيصال'),
                subtitle: 'بالكاميرا الآن',
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              JourneyListRow(
                key: const ValueKey('receipt-source-gallery'),
                icon: LucideIcons.image,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
                title: context.say('اختر من الصور', 'اختاري من الصور'),
                subtitle: 'صورة محفوظة في جوالك',
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  if (source == null || !context.mounted) return null;
  return ImagePicker().pickImage(
    source: source,
    imageQuality: 82,
    maxWidth: 2000,
  );
}

/// Keeps [file] as a receipt of [costId], with [costPaymentId] when it
/// belongs to one payment. When it [replacing] an old one, the new photo is
/// saved first and the old one removed after, so nothing is left half done.
/// True once saved.
Future<bool> saveReceiptImage(
  BuildContext context,
  CostReceiptsApi api,
  XFile file, {
  required String costId,
  String? costPaymentId,
  CostReceipt? replacing,
}) async {
  final uploader = context.read<MediaUploadApi>();
  try {
    final ticket = await uploader.uploadImage(
      file: file,
      purpose: 'cost-receipt',
    );
    await api.add(
      costId,
      attachmentRef: ticket.attachmentRef,
      costPaymentId: costPaymentId,
    );
  } on ApiException catch (error) {
    if (context.mounted) {
      AarastToast.showError(
        context,
        costReceiptErrorMessage(error.serverCode) ?? error.message,
      );
    }
    return false;
  } catch (_) {
    if (context.mounted) {
      AarastToast.showError(context, 'ما قدرنا نحفظ الإيصال الآن');
    }
    return false;
  }
  if (replacing != null) {
    try {
      await api.delete(replacing.weddingCostId, replacing.id);
    } on ApiException catch (error) {
      if (context.mounted) AarastToast.showError(context, error.message);
    }
  }
  if (context.mounted) AarastToast.showSuccess(context, 'انحفظ الإيصال');
  return true;
}

/// Asks before removing a receipt; the payment itself stays.
Future<bool> confirmRemoveReceipt(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AarastDialog(
      title: Text(context.say('تشيل الإيصال؟', 'تشيلين الإيصال؟')),
      content: const Text('الصورة تنحذف، والدفعة تبقى.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('رجوع'),
        ),
        FilledButton(
          key: const ValueKey('receipt-remove-confirm'),
          style: FilledButton.styleFrom(backgroundColor: AarastV3Color.danger),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(context.say('شيله', 'شيليه')),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Removes [receipt]. True once removed.
Future<bool> deleteReceipt(
  BuildContext context,
  CostReceiptsApi api,
  CostReceipt receipt,
) async {
  try {
    await api.delete(receipt.weddingCostId, receipt.id);
    return true;
  } on ApiException catch (error) {
    if (context.mounted) AarastToast.showError(context, error.message);
  }
  return false;
}

/// The receipt full size. Its link lasts about two minutes, so callers
/// reload their list afterwards.
Future<ReceiptViewerAction?> showReceiptViewer(
  BuildContext context,
  CostReceipt receipt, {
  required bool canManage,
}) {
  return showDialog<ReceiptViewerAction>(
    context: context,
    builder: (dialogContext) => AarastDialog(
      title: const Text('الإيصال'),
      scrollable: false,
      content: InteractiveViewer(
        child: Image.network(
          receipt.downloadUrl,
          errorBuilder: (_, _, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.say(
                'انتهى الرابط. سكّر وافتح الإيصال مرة ثانية.',
                'انتهى الرابط. سكّري وافتحي الإيصال مرة ثانية.',
              ),
            ),
          ),
        ),
      ),
      actions: [
        if (canManage) ...[
          TextButton(
            key: const ValueKey('receipt-viewer-remove'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(ReceiptViewerAction.remove),
            child: Text(
              context.say('شيله', 'شيليه'),
              style: const TextStyle(color: AarastV3Color.danger),
            ),
          ),
          TextButton(
            key: const ValueKey('receipt-viewer-replace'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(ReceiptViewerAction.replace),
            child: Text(context.say('بدّله', 'بدّليه')),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.say('سكّر', 'سكّري')),
        ),
      ],
    ),
  );
}

/// One receipt photo, or the empty frame that asks for one.
class ReceiptThumb extends StatelessWidget {
  const ReceiptThumb({
    required this.receipt,
    required this.onTap,
    this.size = 92,
    this.width,
    super.key,
  });

  /// Null draws the missing frame with a camera.
  final CostReceipt? receipt;
  final VoidCallback? onTap;
  final double size;

  /// Wider than tall inside a grid cell; square by default.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final receipt = this.receipt;
    final width = this.width ?? size;
    final missing = Container(
      width: width,
      height: size,
      decoration: BoxDecoration(
        color: AarastV3Color.canvas,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AarastV3Color.lineStrong),
      ),
      child: const Icon(
        LucideIcons.camera,
        size: 28,
        color: AarastV3Color.textFaint,
      ),
    );
    final Widget child = receipt == null
        ? missing
        : ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              receipt.downloadUrl,
              width: width,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: width,
                height: size,
                color: context.accent.primarySoft,
                child: Icon(
                  LucideIcons.fileText,
                  size: 28,
                  color: context.accent.primary,
                ),
              ),
            ),
          );
    if (onTap == null) return child;
    return Semantics(
      button: true,
      label: receipt == null
          ? context.say('أضف إيصال', 'أضيفي إيصال')
          : context.say('افتح الإيصال', 'افتحي الإيصال'),
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(onTap: onTap!, child: child),
    );
  }
}
