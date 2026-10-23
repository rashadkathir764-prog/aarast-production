import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/marketplace_provider.dart';

/// Rates a provider 1–5 with an optional comment (3.1). The server accepts it
/// only after a confirmed booking's day has passed (F10).
Future<void> showProviderReviewSheet(
  BuildContext context, {
  required String providerId,
  String? providerName,
}) {
  return showAarastBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _ProviderReviewSheet(
      providerId: providerId,
      providerName: providerName,
      marketplace: context.read<ProviderMarketplaceProvider>(),
    ),
  );
}

class _ProviderReviewSheet extends StatefulWidget {
  const _ProviderReviewSheet({
    required this.providerId,
    required this.providerName,
    required this.marketplace,
  });

  final String providerId;
  final String? providerName;
  final ProviderMarketplaceProvider marketplace;

  @override
  State<_ProviderReviewSheet> createState() => _ProviderReviewSheetState();
}

class _ProviderReviewSheetState extends State<_ProviderReviewSheet> {
  final _comment = TextEditingController();
  int _rating = 0;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await widget.marketplace.reviewProvider(
      providerId: widget.providerId,
      rating: _rating,
      comment: _comment.text,
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      AarastToast.showSuccess(context, 'شكرًا، نُشر تقييمك.');
      return;
    }
    setState(() {
      _sending = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AarastBottomSheetHandle(),
              Text(
                widget.providerName == null
                    ? 'كيف كانت تجربتك؟'
                    : 'كيف كانت تجربتك مع ${widget.providerName}؟',
                style: textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      key: Key('review-star-$star'),
                      onPressed: _sending
                          ? null
                          : () => setState(() => _rating = star),
                      iconSize: 34,
                      icon: Icon(
                        LucideIcons.star,
                        color: star <= _rating
                            ? AppTheme.focus
                            : AppTheme.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('review-comment'),
                controller: _comment,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'تعليقك (اختياري)',
                ),
              ),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                key: const Key('review-submit'),
                onPressed: _rating == 0 || _sending ? null : _submit,
                child: Text(_sending ? 'جارٍ الإرسال...' : 'نشر التقييم'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
