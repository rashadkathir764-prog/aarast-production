import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../marketplace/marketplace_api.dart'
    show MarketplaceBooking, bookingStatusLabel;
import '../providers/provider_dashboard_provider.dart';

/// The provider's side of a booking (V1 checklist 4.6): confirm or decline a
/// request, or cancel a confirmed day. Tracking only — no deposit.
class ProviderBookingPanel extends StatelessWidget {
  const ProviderBookingPanel({required this.booking, super.key});

  final MarketplaceBooking booking;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final submitting = context.watch<ProviderDashboardProvider>().isSubmitting;
    final confirmed =
        booking.isConfirmed || booking.lifecycleStatus == 'COMPLETED';
    return Container(
      key: Key('provider-booking-${booking.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: booking.isRequested
            ? AppTheme.brandMuted
            : confirmed
            ? AppTheme.successSoft
            : AppTheme.canvas,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                confirmed ? LucideIcons.calendarCheck : LucideIcons.calendarClock,
                size: 20,
                color: confirmed ? AppTheme.success : AppTheme.brand,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${bookingStatusLabel(booking, forProvider: true)} · ${formatArabicDate(booking.eventDate)}',
                  style: textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (booking.isRequested) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('provider-booking-decline-${booking.id}'),
                    onPressed: submitting
                        ? null
                        : () => _decide(context, 'decline'),
                    child: const Text('اعتذار'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: Key('provider-booking-confirm-${booking.id}'),
                    onPressed: submitting
                        ? null
                        : () => _decide(context, 'confirm'),
                    child: const Text('تأكيد الحجز'),
                  ),
                ),
              ],
            ),
          ] else if (booking.isConfirmed)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: Key('provider-booking-cancel-${booking.id}'),
                onPressed: submitting ? null : () => _decide(context, 'cancel'),
                child: const Text('إلغاء الحجز'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _decide(BuildContext context, String action) async {
    if (action != 'confirm') {
      final sure = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AarastDialog(
          title: Text(action == 'decline' ? 'الاعتذار عن الحجز؟' : 'إلغاء الحجز؟'),
          content: const Text('سيصل إشعار للعميل بقرارك.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(action == 'decline' ? 'اعتذار' : 'إلغاء الحجز'),
            ),
          ],
        ),
      );
      if (sure != true || !context.mounted) return;
    }
    final dashboard = context.read<ProviderDashboardProvider>();
    final ok = await dashboard.decideBooking(
      bookingId: booking.id,
      action: action,
    );
    if (!context.mounted) return;
    if (ok) {
      AarastToast.showSuccess(
        context,
        switch (action) {
          'confirm' => 'تم تأكيد الحجز وإبلاغ العميل.',
          'decline' => 'تم الاعتذار وإبلاغ العميل.',
          _ => 'أُلغي الحجز وأُبلغ العميل.',
        },
      );
    } else {
      AarastToast.showError(
        context,
        dashboard.errorMessage ?? 'تعذر تحديث الحجز.',
      );
    }
  }
}

/// A newly approved provider lands on a dashboard of zeros. This names what
/// customers still cannot see and leads to it; customers find the provider
/// only once one service is published (field test Q14).
class ProviderSetupChecklist extends StatelessWidget {
  const ProviderSetupChecklist({required this.dashboard, super.key});

  final ProviderDashboardProvider dashboard;

  static bool _hasService(ProviderDashboardProvider dashboard) =>
      dashboard.services.any((service) => service.isActive);

  static bool _hasLogo(ProviderDashboardProvider dashboard) =>
      dashboard.profile?.logoUrl?.trim().isNotEmpty == true;

  static bool _hasDescription(ProviderDashboardProvider dashboard) =>
      dashboard.profile?.description?.trim().isNotEmpty == true;

  static bool isIncomplete(ProviderDashboardProvider dashboard) =>
      !_hasService(dashboard) ||
      !_hasLogo(dashboard) ||
      !_hasDescription(dashboard);

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        done: _hasService(dashboard),
        title: 'أضف خدمة واحدة على الأقل بسعرها',
        hint: 'لن يظهر ملفك للعملاء قبلها.',
        route: AppRouter.providerServiceNew,
      ),
      (
        done: _hasLogo(dashboard),
        title: 'أضف شعارك أو صورة نشاطك',
        hint: 'الملف بصورة يجذب طلبات أكثر.',
        route: AppRouter.providerProfileEdit,
      ),
      (
        done: _hasDescription(dashboard),
        title: 'اكتب نبذة عن نشاطك',
        hint: 'ما تقدّمه وما يميزك.',
        route: AppRouter.providerProfileEdit,
      ),
    ];
    final remaining = steps.where((step) => !step.done).length;
    final textTheme = Theme.of(context).textTheme;
    return AarastCard(
      key: const Key('provider-setup-checklist'),
      color: AppTheme.brandMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'أكمل ملفك ليراك العملاء',
            style: textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            remaining == 1 ? 'بقيت خطوة واحدة.' : 'بقيت $remaining خطوات.',
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final step in steps)
            InkWell(
              onTap: step.done ? null : () => context.push(step.route),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      step.done ? LucideIcons.checkCircle2 : LucideIcons.circle,
                      size: 20,
                      color: step.done ? AppTheme.success : AppTheme.brand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: textTheme.bodyMedium?.copyWith(
                              color: step.done
                                  ? AppTheme.textSecondary
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                              decoration: step.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (!step.done)
                            Text(
                              step.hint,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!step.done)
                      const Icon(
                        LucideIcons.chevronLeft,
                        size: 18,
                        color: AppTheme.brand,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Upcoming confirmed days and open booking requests, and the days the
/// provider closed on their calendar (V1 checklist 4.6).
class ProviderBookingsSection extends StatelessWidget {
  const ProviderBookingsSection({required this.dashboard, super.key});

  final ProviderDashboardProvider dashboard;

  @override
  Widget build(BuildContext context) {
    final bookings = dashboard.bookings;
    final requested = bookings.where((item) => item.isRequested).length;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AarastSectionHeader(
          title: 'حجوزاتك',
          subtitle: requested > 0
              ? '$requested ${requested == 1 ? 'طلب حجز ينتظر ردّك' : 'طلبات حجز تنتظر ردّك'}'
              : 'الأيام المؤكدة القادمة.',
          icon: LucideIcons.calendarCheck,
          actionLabel: 'الأيام المغلقة',
          onAction: () => _showBlockedDatesSheet(context),
        ),
        const SizedBox(height: 10),
        if (bookings.isEmpty)
          Text(
            'لا توجد حجوزات بعد. بعد قبول العميل عرضك يطلب حجز اليوم، فتؤكده من هنا.',
            style: textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          )
        else
          for (final booking in bookings.take(5)) ...[
            if (booking.customerName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  booking.customerName!,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ProviderBookingPanel(booking: booking),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

Future<void> _showBlockedDatesSheet(BuildContext context) {
  return showAarastBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (sheetContext) => const _BlockedDatesSheet(),
  );
}

class _BlockedDatesSheet extends StatelessWidget {
  const _BlockedDatesSheet();

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AarastBottomSheetHandle(),
            Text(
              'الأيام المغلقة',
              style: textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'لن يستطيع العملاء طلب حجز هذه الأيام. الأيام المحجوزة تُغلق تلقائيًا.',
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            if (dashboard.blockedDates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'لم تغلق أي يوم.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final day in dashboard.blockedDates)
                      ListTile(
                        key: Key(
                          'blocked-date-${MarketplaceBooking.dayParam(day)}',
                        ),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          LucideIcons.calendarX,
                          color: AppTheme.brand,
                        ),
                        title: Text(formatArabicDate(day)),
                        trailing: TextButton(
                          onPressed: dashboard.isSubmitting
                              ? null
                              : () => dashboard.unblockDate(day),
                          child: const Text('فتح'),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('blocked-date-add'),
              onPressed: dashboard.isSubmitting
                  ? null
                  : () => _pickAndBlock(context, dashboard),
              icon: const Icon(LucideIcons.calendarPlus),
              label: const Text('إغلاق يوم'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndBlock(
    BuildContext context,
    ProviderDashboardProvider dashboard,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 1095)),
    );
    if (picked == null || !context.mounted) return;
    final ok = await dashboard.blockDate(picked);
    if (!context.mounted) return;
    if (!ok) {
      AarastToast.showError(
        context,
        dashboard.errorMessage ?? 'تعذر إغلاق اليوم.',
      );
    }
  }
}
