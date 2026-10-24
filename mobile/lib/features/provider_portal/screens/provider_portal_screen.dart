import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/routing/root_tab_back_scope.dart';
import '../../chat/chat_api.dart' show ChatProvider, ConversationListView;
import '../../marketplace/marketplace_api.dart' show ProviderDashboardProfile;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_portal_bottom_nav.dart';
import 'provider_portal_tabs.dart';

class ProviderPortalScreen extends StatefulWidget {
  const ProviderPortalScreen({this.initialTab, super.key});

  /// The tab a link opens on: `requests` for the requests tab
  /// ([AppRouter.providerRequestsTab]); the home tab otherwise.
  final String? initialTab;

  @override
  State<ProviderPortalScreen> createState() => _ProviderPortalScreenState();
}

int? _tabIndexOf(String? tab) => switch (tab) {
  'requests' => 1,
  _ => null,
};

class _ProviderPortalScreenState extends State<ProviderPortalScreen> {
  late int _activeIndex = _tabIndexOf(widget.initialTab) ?? 0;

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
    final canUseOperations = dashboard.canUseProviderOperations;
    final unreadMessages = context
        .watch<ChatProvider>()
        .conversations
        .fold<int>(0, (sum, item) => sum + item.unreadMessageCount);
    return RootTabBackScope(
      activeIndex: _activeIndex,
      onReturnToRoot: () => _openTab(0),
      child: AarastScreenFrame(
        extendBody: true,
        safeAreaBottom: false,
        bottomNavigationBar: ProviderPortalBottomNav(
          activeIndex: _activeIndex,
          unreadMessages: unreadMessages,
          onSelected: _openTab,
        ),
        child: IndexedStack(
          index: _activeIndex,
          children: [
            ProviderHomeTab(onOpenTab: _openTab),
            canUseOperations
                ? const ProviderRequestsTab()
                : _ProviderOperationsUnavailable(profile: dashboard.profile),
            canUseOperations
                ? const ProviderServicesTab()
                : _ProviderOperationsUnavailable(profile: dashboard.profile),
            canUseOperations
                ? const ConversationListView(embedded: true)
                : _ProviderOperationsUnavailable(profile: dashboard.profile),
            const ProviderProfileTab(),
          ],
        ),
      ),
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

class _ProviderOperationsUnavailable extends StatelessWidget {
  const _ProviderOperationsUnavailable({required this.profile});

  final ProviderDashboardProfile? profile;

  @override
  Widget build(BuildContext context) {
    final status = profile?.status.toUpperCase();
    final copy = switch (status) {
      'NEEDS_CHANGES' => (
        'أكمل التعديلات المطلوبة',
        profile?.reviewNote?.trim().isNotEmpty == true
            ? profile!.reviewNote!.trim()
            : 'عدّل بيانات ملفك حسب ملاحظة الإدارة، وبعدها كلّم الدعم عشان يراجعونه.',
      ),
      'REJECTED' => (
        'الطلب غير معتمد',
        profile?.reviewNote?.trim().isNotEmpty == true
            ? profile!.reviewNote!.trim()
            : 'الإدارة ما اعتمدت طلبك، والملف ما يتعدّل. لو عندك سؤال كلّم الدعم.',
      ),
      'SUSPENDED' => (
        'عمليات المزوّد موقوفة',
        profile?.reviewNote?.trim().isNotEmpty == true
            ? profile!.reviewNote!.trim()
            : 'لا يمكن إدارة الخدمات أو الطلبات حتى تعيد الإدارة تفعيل الحساب.',
      ),
      'PENDING' => (
        'الطلب قيد المراجعة',
        'ستتاح الخدمات والطلبات والمحادثات بعد اعتماد حساب المزوّد.',
      ),
      _ => (
        'عمليات المزوّد غير متاحة',
        'اسحب الصفحة لتحت عشان تتحدّث حالة حسابك.',
      ),
    };
    return RefreshIndicator(
      color: AarastV3Color.primary,
      onRefresh: context.read<ProviderDashboardProvider>().loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 128),
        children: [
          AarastEmptyState(
            icon: LucideIcons.shieldAlert,
            title: copy.$1,
            message: copy.$2,
          ),
          const SizedBox(height: 16),
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
