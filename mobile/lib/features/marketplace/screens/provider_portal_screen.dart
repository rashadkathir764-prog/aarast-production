import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/aarast_ui.dart';
import '../../../core/routing/root_tab_back_scope.dart';
import '../../chat/providers/chat_provider.dart';
import '../../chat/widgets/conversation_list_view.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderDashboardProvider>().loadDashboard();
      context.read<ChatProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
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
            const ProviderRequestsTab(),
            const ProviderServicesTab(),
            const ConversationListView(embedded: true),
            const ProviderProfileTab(),
          ],
        ),
      ),
    );
  }

  void _openTab(int index) => setState(() => _activeIndex = index);
}
