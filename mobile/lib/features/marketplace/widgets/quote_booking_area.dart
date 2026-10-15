import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';

/// After acceptance the customer reserves the wedding day with the provider
/// (V1 checklist 4.6): ask, see the provider's answer, cancel or ask again,
/// and review the provider once the day has passed (3.1).
/// Tracking only — no deposit or payment.
class QuoteBookingArea extends StatelessWidget {
  const QuoteBookingArea({
    required this.quote,
    required this.isSubmitting,
    super.key,
  });

  final QuoteRequest quote;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final booking = quote.booking;
    final textTheme = Theme.of(context).textTheme;
    if (booking != null && booking.isOpen ||
        booking?.lifecycleStatus == 'COMPLETED') {
      final confirmed =
          booking!.isConfirmed || booking.lifecycleStatus == 'COMPLETED';
      return Container(
        key: Key('quote-booking-${quote.id}'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: confirmed ? AppTheme.successSoft : AppTheme.canvas,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: confirmed
                ? AppTheme.success.withValues(alpha: 0.3)
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              confirmed ? LucideIcons.calendarCheck : LucideIcons.hourglass,
              color: confirmed ? AppTheme.success : AppTheme.focus,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookingStatusLabel(booking),
                    style: textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatArabicDate(booking.eventDate),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (booking.lifecycleStatus == 'COMPLETED')
              TextButton(
                key: Key('quote-booking-review-${quote.id}'),
                onPressed: () => showProviderReviewSheet(
                  context,
                  providerId: quote.providerId,
                  providerName: quote.provider?.businessName,
                ),
                child: const Text('قيّم المزوّد'),
              )
            else if (booking.isOpen)
              TextButton(
                key: Key('quote-booking-cancel-${quote.id}'),
                onPressed: isSubmitting ? null : () => _cancel(context),
                child: Text(booking.isConfirmed ? 'إلغاء الحجز' : 'إلغاء الطلب'),
              ),
          ],
        ),
      );
    }

    final declined = booking?.status == 'DECLINED';
    final day = quote.eventDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (booking != null) ...[
          Text(
            declined
                ? 'اعتذر المزوّد عن ${formatArabicDate(booking.eventDate)}${booking.note == null ? '' : ': ${booking.note}'}. يمكنك طلب يوم آخر.'
                : '${bookingStatusLabel(booking)}. يمكنك طلب الحجز من جديد.',
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          key: Key('quote-booking-request-${quote.id}'),
          onPressed: isSubmitting
              ? null
              : () => day == null || declined
                    ? _pickAndRequest(context)
                    : _request(context, null),
          icon: const Icon(LucideIcons.calendarPlus, size: 18),
          label: Text(
            day == null || declined
                ? 'اختر يوم الحجز'
                : 'اطلب حجز يوم ${formatArabicCompactDate(day)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (day != null && !declined)
          TextButton(
            key: Key('quote-booking-other-day-${quote.id}'),
            onPressed: isSubmitting ? null : () => _pickAndRequest(context),
            child: const Text('يوم آخر'),
          ),
      ],
    );
  }

  Future<void> _pickAndRequest(BuildContext context) async {
    releaseFieldFocus();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = quote.eventDate != null && !quote.eventDate!.isBefore(today)
        ? quote.eventDate!
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 1095)),
    );
    if (picked == null || !context.mounted) return;
    await _request(context, picked);
  }

  Future<void> _request(BuildContext context, DateTime? day) async {
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final ok = await marketplace.requestBooking(quote, eventDate: day);
    if (!context.mounted) return;
    if (ok) {
      AarastToast.showSuccess(
        context,
        'أرسلنا طلب الحجز للمزوّد. سنخبرك عند تأكيده.',
      );
    } else {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'تعذر إرسال طلب الحجز.',
      );
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: Text(
          quote.booking!.isConfirmed ? 'إلغاء الحجز؟' : 'إلغاء طلب الحجز؟',
        ),
        content: const Text('سيصل إشعار للمزوّد ويصبح اليوم متاحًا عنده.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            key: const Key('quote-booking-cancel-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('إلغاء الحجز'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final ok = await marketplace.cancelBooking(quote);
    if (!context.mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'أُلغي الحجز.');
    } else {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'تعذر إلغاء الحجز.',
      );
    }
  }
}

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
