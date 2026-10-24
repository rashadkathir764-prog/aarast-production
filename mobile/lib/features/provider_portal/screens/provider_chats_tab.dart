import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../chat/chat_api.dart' show ChatConversation, ChatProvider;
import '../../marketplace/marketplace_api.dart' show QuoteRequest;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_request_parts.dart';

/// p33 «الرسائل»: one row per customer, with his request's status word, the
/// request's service and day, the last message, when, and how many are
/// unread. The name is the customer's (D35); a voice preview never shows
/// (no voice notes, F14).
class ProviderChatsTab extends StatelessWidget {
  const ProviderChatsTab({this.now, super.key});

  /// The clock for «أمس» and the weekday; tests pin it.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final dashboard = context.watch<ProviderDashboardProvider>();
    final clock = now ?? DateTime.now();
    final conversations = chat.conversations;
    return RefreshIndicator(
      color: AarastV3Color.primary,
      onRefresh: chat.initialize,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 128),
        children: [
          const JourneyTabHeader(title: 'الرسائل', status: 'مع العرسان'),
          if (chat.isLoading && conversations.isEmpty)
            const JourneyListState(
              phase: JourneyListPhase.loading,
              section: JourneySection.home,
            )
          else if (chat.errorMessage != null && conversations.isEmpty)
            JourneyListState(
              phase: JourneyListPhase.error,
              section: JourneySection.home,
              onRetry: chat.initialize,
            )
          else if (conversations.isEmpty)
            const JourneyListState(
              key: Key('provider-chats-empty'),
              phase: JourneyListPhase.empty,
              section: JourneySection.home,
              emptyIcon: LucideIcons.messageCircle,
              emptyTitle: 'ما فيه محادثات لسا',
              emptyMessage: 'أول ما يطلب منك عريس عرض، تبدأ محادثتكم هنا.',
            )
          else
            JourneyList(
              children: [
                for (var i = 0; i < conversations.length; i++)
                  ProviderChatRow(
                    key: Key('provider-chat-${conversations[i].id}'),
                    conversation: conversations[i],
                    quote: _quoteOf(dashboard, conversations[i]),
                    dashboard: dashboard,
                    color: _avatarTurns[i % _avatarTurns.length],
                    when: providerChatWhen(
                      conversations[i].lastMessage?.createdAt ??
                          conversations[i].lastActivityAt,
                      clock,
                    ),
                  ),
              ],
            ),
          if (chat.canLoadMoreConversations)
            Center(
              child: JourneyTextAction(
                label: 'اعرض أكثر',
                icon: LucideIcons.chevronDown,
                color: AarastV3Color.primary,
                onPressed: chat.isLoadingMoreConversations
                    ? null
                    : chat.loadMoreConversations,
              ),
            ),
        ],
      ),
    );
  }

  static QuoteRequest? _quoteOf(
    ProviderDashboardProvider dashboard,
    ChatConversation conversation,
  ) {
    final id = conversation.latestQuoteRequest?.id;
    if (id == null) return null;
    for (final quote in dashboard.quoteRequests) {
      if (quote.id == id) return quote;
    }
    return null;
  }
}

/// The avatars' colours in turn, as drawn (teal, rose, sky).
const _avatarTurns = [
  AarastV3Color.primary,
  AarastV3Color.rose,
  AarastV3Color.cobalt,
];

/// «9:40» today, «أمس», the weekday within a week, else «12 أكتوبر».
String providerChatWhen(DateTime at, DateTime now) {
  final local = at.toLocal();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(local.year, local.month, local.day)).inDays;
  if (days <= 0) {
    return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }
  if (days == 1) return 'أمس';
  if (days < 7) return formatArabicWeekday(local);
  return formatArabicDayMonth(local);
}

/// One conversation: letter avatar, name and status word, «الخدمة · اليوم»,
/// the last message (dark while unread), when, and the unread count.
class ProviderChatRow extends StatelessWidget {
  const ProviderChatRow({
    required this.conversation,
    required this.quote,
    required this.dashboard,
    required this.color,
    required this.when,
    super.key,
  });

  final ChatConversation conversation;
  final QuoteRequest? quote;
  final ProviderDashboardProvider dashboard;
  final Color color;
  final String when;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadMessageCount;
    final name = conversation.counterpartName;
    final quote = this.quote;
    final service =
        (quote?.service?.title ??
                conversation.latestQuoteRequest?.service?.title)
            ?.trim() ??
        '';
    final about = [
      if (service.isNotEmpty) service,
      if (quote?.eventDate case final day?) formatArabicDayMonth(day),
    ].join(' · ');
    final body = conversation.lastMessage?.body.trim() ?? '';
    final last = body.isNotEmpty
        ? body
        : service.isNotEmpty
        ? 'طلب: $service'
        : 'ما فيه رسائل لسا';
    final state = quote == null
        ? null
        : providerCaseOf(quote, providerBookingOf(quote, dashboard));
    return AarastPressable(
      onTap: () => context.push(AppRouter.conversation(conversation.id)),
      semanticLabel: [
        name,
        ?state?.tag.$1,
        last,
        if (unread > 0) '$unread ما قريتها',
      ].join('، '),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            JourneyAvatar(
              letter: name.characters.first,
              color: color,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: JourneyType.of(
                            JourneyType.body,
                            weight: JourneyType.bold,
                          ),
                        ),
                      ),
                      if (state != null) ...[
                        const SizedBox(width: 6),
                        ProviderCaseTag(state: state),
                      ],
                    ],
                  ),
                  if (about.isNotEmpty)
                    Text(
                      about,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JourneyType.of(
                        JourneyType.caption,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  Text(
                    last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JourneyType.of(
                      JourneyType.detail,
                      color: unread > 0
                          ? AarastV3Color.ink
                          : AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  when,
                  style: JourneyType.of(
                    JourneyType.tabLabel,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AarastV3Color.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$unread',
                      style: JourneyType.of(
                        JourneyType.tabLabel,
                        weight: JourneyType.bold,
                        color: AarastV3Color.onPrimary,
                      ),
                    ),
                  ),
                ] else if (conversation.muted) ...[
                  const SizedBox(height: 4),
                  const Icon(
                    LucideIcons.bellOff,
                    size: 16,
                    color: AarastV3Color.textMuted,
                    semanticLabel: 'مكتومة',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
