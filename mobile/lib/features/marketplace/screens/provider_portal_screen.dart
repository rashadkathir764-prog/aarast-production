import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/aarast_ui.dart';
import '../../../core/routing/root_tab_back_scope.dart';
import '../../account_contexts/providers/account_context_controller.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/widgets/conversation_list_view.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/provider_portal_bottom_nav.dart';
import 'provider_portal_tabs.dart';

class ProviderPortalScreen extends StatefulWidget {
  const ProviderPortalScreen({super.key});

  @override
  State<ProviderPortalScreen> createState() => _ProviderPortalScreenState();
}

class _ProviderPortalScreenState extends State<ProviderPortalScreen> {
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializePortal());
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
    final contexts = context.read<AccountContextController?>();
    await contexts?.refresh();
    if (!mounted) return;

    final dashboard = context.read<ProviderDashboardProvider>();
    await dashboard.loadDashboard();
    if (!mounted || !dashboard.canUseProviderOperations) return;
    await context.read<ChatProvider>().initialize();
  }

  void _openTab(int index) => setState(() => _activeIndex = index);
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
            : 'راجع بيانات ملفك ثم حدّثها حسب ملاحظة الإدارة.',
      ),
      'REJECTED' => (
        'الطلب غير معتمد',
        profile?.reviewNote?.trim().isNotEmpty == true
            ? profile!.reviewNote!.trim()
            : 'راجع ملاحظة الإدارة قبل التواصل مع الدعم أو تحديث الملف.',
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
        'حدّث الصفحة للاطلاع على حالة حساب المزوّد الحالية.',
      ),
    };
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 128),
      children: [
        AarastEmptyState(
          icon: LucideIcons.shieldAlert,
          title: copy.$1,
          message: copy.$2,
        ),
      ],
    );
  }
}
