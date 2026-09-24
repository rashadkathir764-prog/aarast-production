part of 'app_router.dart';

// Secure quote conversations.
List<RouteBase> _conversationRoutes() => [
  // Secure quote chat: every list, detail, and quote entry route requires
  // a real account. Backend ownership still limits each conversation to
  // the requester and the provider attached to that quote request.
  GoRoute(
    path: AppRouter.conversations,
    builder: (context, state) => ProviderAuthGate(
      resumeLocation: state.uri.toString(),
      child: const ConversationListView(),
    ),
  ),
  GoRoute(
    path: '/conversations/:id',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return ProviderAuthGate(
        resumeLocation: state.uri.toString(),
        child: ChatScreen(conversationId: id),
      );
    },
  ),
  GoRoute(
    path: '/quotes/:id/conversation',
    builder: (context, state) {
      final id = state.pathParameters['id'] ?? '';
      return ProviderAuthGate(
        resumeLocation: state.uri.toString(),
        child: QuoteConversationEntryScreen(
          quoteRequestId: id,
          returnQuoteToMarketplace:
              state.extra ==
              ProviderMarketplaceLaunchOrigin.ownerMainShellProviders,
        ),
      );
    },
  ),
];
