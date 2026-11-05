import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/offline/offline_status_widgets.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/routing/root_tab_back_scope.dart';
import '../../chat/chat_api.dart' show ChatProvider;
import '../../marketplace/marketplace_api.dart'
    show ProviderMarketplaceProvider;
import '../data/provider_approval_ledger.dart';
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_join_parts.dart' show providerPickOption;
import '../widgets/provider_joining_service_sheet.dart';
import '../widgets/provider_portal_bottom_nav.dart';
import 'provider_approved_screen.dart';
import 'provider_changes_screen.dart';
import 'provider_pending_screen.dart';
import 'provider_portal_tabs.dart';
import 'provider_rejected_screen.dart';
import 'provider_suspended_screen.dart';

class ProviderPortalScreen extends StatefulWidget {
  const ProviderPortalScreen({this.initialTab, super.key});

  /// The tab a link opens on: `requests` for the requests tab
  /// ([AppRouter.providerRequestsTab]), `calendar` for the calendar,
  /// `profile` for «ملفي» (p35, where his featured placement shows: the
  /// notices about it open there, B-19); the home tab otherwise.
  final String? initialTab;

  @override
  State<ProviderPortalScreen> createState() => _ProviderPortalScreenState();
}

int? _tabIndexOf(String? tab) => switch (tab) {
  'requests' => 1,
  'calendar' => 2,
  'profile' => 4,
  _ => null,
};

class _ProviderPortalScreenState extends State<ProviderPortalScreen> {
  late int _activeIndex = _tabIndexOf(widget.initialTab) ?? 0;

  /// Whether p10 is due for the profile's current status; null while this
  /// phone's record is read.
  bool? _welcome;
  String? _notedStatus;

  /// Why p09's or p11's own last step failed (sending, reopening, the
  /// category, a refresh). Each screen and sheet shows only its own error:
  /// a failed save in the joining-service sheet stays in that sheet.
  String? _stepError;

  void _noteStatus(String providerId, String status) {
    final key = '$providerId:$status';
    if (key == _notedStatus) return;
    _notedStatus = key;
    _stepError = null;
    _welcome = status == 'ACTIVE' ? null : false;
    unawaited(_readWelcome(providerId, status, key));
  }

  Future<void> _readWelcome(
    String providerId,
    String status,
    String key,
  ) async {
    var due = false;
    try {
      final ledger = ProviderApprovalLedger(
        await SharedPreferences.getInstance(),
      );
      due = await ledger.welcomeDue(providerId, status);
    } on Object catch (error) {
      debugPrint('Provider welcome not read: $error');
    }
    if (!mounted || key != _notedStatus) return;
    setState(() => _welcome = due);
  }

  Future<void> _welcomed(String providerId) async {
    setState(() => _welcome = false);
    try {
      final ledger = ProviderApprovalLedger(
        await SharedPreferences.getInstance(),
      );
      await ledger.markWelcomed(providerId);
    } on Object catch (error) {
      debugPrint('Provider welcome not remembered: $error');
    }
  }

  Future<void> _openFirstStep(String providerId, ProviderFirstStep step) async {
    await _welcomed(providerId);
    if (!mounted) return;
    switch (step) {
      case ProviderFirstStep.calendar:
        _openTab(2);
      case ProviderFirstStep.services:
        unawaited(context.push(AppRouter.providerServiceNew));
      case ProviderFirstStep.notifications:
        unawaited(context.push(AppRouter.providerSettings));
    }
  }

  @override
  void didUpdateWidget(covariant ProviderPortalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The portal keeps its state when a link to one of its tabs arrives.
    final index = _tabIndexOf(widget.initialTab);
    if (index != null && widget.initialTab != oldWidget.initialTab) {
      _activeIndex = index;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      appLogEvent(
        'DASHBOARD_BUILT',
        category: AppLogCategory.provider,
        screen: 'ProviderPortalScreen',
        reason: 'first_frame_completed',
        source: 'ProviderPortalScreen',
      );
      _initializePortal();
    });
  }

  @override
  void dispose() {
    appLogEvent(
      'DASHBOARD_DISPOSED',
      category: AppLogCategory.provider,
      screen: 'ProviderPortalScreen',
      reason: 'widget_disposed',
      source: 'ProviderPortalScreen',
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final profile = dashboard.profile;
    if (profile != null) {
      final status = profile.status.toUpperCase();
      _noteStatus(profile.id, status);
      switch (status) {
        case 'PENDING':
          return ProviderPendingScreen(
            profile: profile,
            onRefresh: dashboard.loadDashboard,
            onEdit: () => _editApplication(profile.fieldNotes),
            onAccount: () => context.push(AppRouter.more),
          );
        case 'NEEDS_CHANGES':
          return ProviderChangesScreen(
            profile: profile,
            service: dashboard.joiningService,
            submitting: dashboard.isSubmitting,
            errorMessage: _stepError,
            onRefresh: _refreshStep,
            onEdit: () => context.push(AppRouter.providerProfileEdit),
            onPickCategory: () => _pickCategory(profile.primaryCategoryId),
            onEditService: () => _editJoiningService(profile.fieldNotes),
            onResubmit: _resubmit,
            onAccount: () => context.push(AppRouter.more),
          );
        case 'REJECTED':
          return ProviderRejectedScreen(
            profile: profile,
            submitting: dashboard.isSubmitting,
            errorMessage: _stepError,
            onRefresh: _refreshStep,
            onReopen: _reopen,
            onSupport: () => context.push(AppRouter.support),
            onAccount: () => context.push(AppRouter.more),
          );
        case 'SUSPENDED':
          return ProviderSuspendedScreen(
            profile: profile,
            upcomingBookings: dashboard.upcomingConfirmedBookings,
            bookingsKnown: !dashboard.bookingsLoadFailed,
            onRefresh: dashboard.loadDashboard,
            onSupport: () => context.push(AppRouter.support),
            onAccount: () => context.push(AppRouter.more),
          );
        case 'ACTIVE' when _welcome == null:
          return const AarastScreenFrame(
            maxWidth: 520,
            backgroundColor: AarastV3Color.canvas,
            child: SizedBox.expand(),
          );
        case 'ACTIVE' when _welcome == true:
          return ProviderApprovedScreen(
            profile: profile,
            onStart: () => _welcomed(profile.id),
            onStep: (step) => _openFirstStep(profile.id, step),
          );
      }
    }
    final canUseOperations = dashboard.canUseProviderOperations;
    final unreadMessages = context
        .watch<ChatProvider>()
        .conversations
        .fold<int>(0, (sum, item) => sum + item.unreadMessageCount);
    return RootTabBackScope(
      activeIndex: _activeIndex,
      onReturnToRoot: () => _openTab(0),
      child: AarastScreenFrame(
        maxWidth: 520,
        backgroundColor: AarastV3Color.canvas,
        extendBody: true,
        safeAreaBottom: false,
        bottomNavigationBar: ProviderPortalBottomNav(
          activeIndex: _activeIndex,
          unreadMessages: unreadMessages,
          waitingRequests: canUseOperations
              ? providerWaitingCount(dashboard)
              : 0,
          onSelected: _openTab,
        ),
        child: Column(
          children: [
            // D87: the same measured line as the couple's shell (D84).
            const OfflineStatusBanner(audience: OfflineAudience.provider),
            Expanded(
              child: IndexedStack(
                index: _activeIndex,
                children: [
                  ProviderHomeTab(onOpenTab: _openTab),
                  canUseOperations
                      ? const ProviderRequestsTab()
                      : const _ProviderOperationsUnavailable(),
                  canUseOperations
                      ? const ProviderCalendarTab()
                      : const _ProviderOperationsUnavailable(),
                  canUseOperations
                      ? const ProviderChatsTab()
                      : const _ProviderOperationsUnavailable(),
                  const ProviderProfileTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// p09 «أرسلت التعديل» (B-01): back to review, which p08 then shows.
  /// When the team rewrote its notes meanwhile, p09 shows the new ones with
  /// the reason the send did not go.
  Future<void> _resubmit() async {
    final sent = await _step(
      (dashboard) => dashboard.resubmitApplication(),
      fallback: 'ما قدرنا نرسل التعديل. جرّب مرة ثانية.',
    );
    if (!mounted || !sent) return;
    AarastToast.showSuccess(context, 'وصلنا تعديلك. نراجعه ونبلغك هنا.');
  }

  /// p11 «تعديل الملف وإعادة التقديم» (B-02).
  void _reopen() {
    unawaited(
      _step(
        (dashboard) => dashboard.reopenApplication(),
        fallback: 'ما قدرنا نفتح ملفك للتعديل. جرّب مرة ثانية.',
      ),
    );
  }

  /// Runs one of p09's or p11's own steps; its failure is that screen's
  /// error, read right after the step and kept here.
  Future<bool> _step(
    Future<bool> Function(ProviderDashboardProvider dashboard) run, {
    required String fallback,
  }) async {
    final dashboard = context.read<ProviderDashboardProvider>();
    setState(() => _stepError = null);
    final done = await run(dashboard);
    if (!mounted) return done;
    setState(
      () => _stepError = done ? null : dashboard.errorMessage ?? fallback,
    );
    return done;
  }

  /// Pulling p09 or p11 down reads the profile again; a failed read is
  /// that screen's error.
  Future<void> _refreshStep() async {
    final dashboard = context.read<ProviderDashboardProvider>();
    await dashboard.loadDashboard();
    if (!mounted) return;
    setState(() => _stepError = dashboard.errorMessage);
  }

  /// p08 «عدّل طلبك»: waiting for review he can fix his profile's details
  /// and the service he joined with (B-10), so the button asks which.
  Future<void> _editApplication(Map<String, String> notes) async {
    final service = context.read<ProviderDashboardProvider>().joiningService;
    final picked = await providerPickOption(
      context,
      title: 'ايش تبي تعدّل؟',
      keyPrefix: 'provider-pending-edit-option',
      options: [
        ('profile', 'بيانات ملفك'),
        (
          'service',
          service == null
              ? 'خدمتك وسعرها'
              : 'خدمة «${service.title.trim()}» وسعرها',
        ),
      ],
      current: null,
    );
    if (!mounted || picked == null) return;
    if (picked == 'service') {
      await _editJoiningService(notes);
    } else {
      unawaited(context.push(AppRouter.providerProfileEdit));
    }
  }

  /// p09's category: before approval he moves the profile, and the service
  /// he joined with follows (B-01).
  Future<void> _pickCategory(String? current) async {
    final marketplace = context.read<ProviderMarketplaceProvider>();
    if (marketplace.categories.isEmpty) await marketplace.loadReferenceData();
    if (!mounted) return;
    final picked = await providerPickOption(
      context,
      title: 'القسم',
      keyPrefix: 'provider-changes-category-option',
      options: [
        for (final category in marketplace.categories)
          (category.id, category.nameAr),
      ],
      current: current,
    );
    if (picked == null || picked == current || !mounted) return;
    await _step(
      (dashboard) => dashboard.updateProfileCategory(picked),
      fallback: 'ما قدرنا نغيّر القسم. جرّب مرة ثانية.',
    );
  }

  /// p09's service: its name, price and words before approval (B-10).
  Future<void> _editJoiningService(Map<String, String> notes) {
    final dashboard = context.read<ProviderDashboardProvider>();
    final service = dashboard.joiningService;
    return showProviderJoiningServiceSheet(
      context,
      title: service?.title,
      price: service?.basePrice,
      about: service?.description,
      note: notes['SERVICE'],
      onSave: (input) async {
        final saved = await dashboard.saveJoiningService(
          title: input.title,
          price: input.price,
          about: input.about,
        );
        return saved
            ? null
            : dashboard.errorMessage ?? 'ما قدرنا نحفظ خدمتك. جرّب مرة ثانية.';
      },
    );
  }

  Future<void> _initializePortal() async {
    final dashboard = context.read<ProviderDashboardProvider>();
    await dashboard.loadDashboard();
    if (!mounted || !dashboard.canUseProviderOperations) return;
    await context.read<ChatProvider>().initialize();
  }

  void _openTab(int index) {
    setState(() => _activeIndex = index);
    // Once the provider moves on, the address drops the tab it was opened
    // on, so the same link opens that tab again next time.
    if (widget.initialTab != null) {
      GoRouter.maybeOf(context)?.go(AppRouter.providerDashboard);
    }
  }
}

/// A tab the server refused although the profile read as active (its
/// status changed meanwhile). Every other status has its own screen: p08,
/// p09, p11 and p12.
class _ProviderOperationsUnavailable extends StatelessWidget {
  const _ProviderOperationsUnavailable();

  @override
  Widget build(BuildContext context) {
    const copy = (
      'عمليات المزود غير متاحة',
      'اسحب الصفحة لتحت عشان تتحدّث حالة حسابك.',
    );
    return RefreshIndicator(
      color: AarastV3Color.primary,
      onRefresh: context.read<ProviderDashboardProvider>().loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AarastV3Space.x5,
          AarastV3Space.x8,
          AarastV3Space.x5,
          AarastV3Density.pageBottom,
        ),
        children: [
          AarastEmptyState(
            icon: LucideIcons.shieldAlert,
            title: copy.$1,
            message: copy.$2,
          ),
          const SizedBox(height: AarastV3Space.x4),
          JourneyButton(
            key: const Key('provider-operations-support'),
            label: 'تواصل مع الدعم',
            icon: LucideIcons.lifeBuoy,
            background: AarastV3Color.primarySoft,
            foreground: AarastV3Color.primary,
            expand: true,
            onPressed: () => context.push(AppRouter.support),
          ),
        ],
      ),
    );
  }
}
