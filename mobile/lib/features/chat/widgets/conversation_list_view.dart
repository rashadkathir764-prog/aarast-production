import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';

/// f08 «المحادثات»: one row per provider, its kind's icon, the last
/// message (bold while unread), when, and how many are unread.
class ConversationListView extends StatefulWidget {
  const ConversationListView({
    this.embedded = false,
    this.iconFor,
    this.now,
    super.key,
  });

  final bool embedded;

  /// The icon of the service a conversation is about; the providers tab
  /// owns that map. A store when not given.
  final IconData Function(String? serviceTitle)? iconFor;

  /// The clock for «أمس» and the weekday; tests pin it.
  final DateTime? now;

  @override
  State<ConversationListView> createState() => _ConversationListViewState();
}

class _ConversationListViewState extends State<ConversationListView> {
  ChatProvider? _chat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.embedded) return;
    // Opened straight on this page, the per-plan chat store is swapped once
    // the plan is chosen; the list loads again on the current one.
    final chat = context.read<ChatProvider>();
    if (identical(chat, _chat)) return;
    _chat = chat;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(chat, _chat)) chat.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final now = widget.now ?? appNow();
    final content = RefreshIndicator(
      color: context.accent.primary,
      onRefresh: chat.initialize,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 14, 16, widget.embedded ? 124 : 28),
        children: [
          if (!widget.embedded)
            JourneySubHeader(
              title: 'المحادثات',
              onBack: () => context.popOrGo(AppRouter.home),
            ),
          if (chat.isLoading && chat.conversations.isEmpty)
            const JourneyListState(
              phase: JourneyListPhase.loading,
              section: JourneySection.providers,
            )
          else if (chat.errorMessage != null && chat.conversations.isEmpty)
            JourneyListState(
              phase: JourneyListPhase.error,
              section: JourneySection.providers,
              onRetry: chat.initialize,
            )
          else if (chat.conversations.isEmpty)
            const JourneyListState(
              key: ValueKey('conversations-empty'),
              phase: JourneyListPhase.empty,
              section: JourneySection.providers,
              emptyIcon: LucideIcons.messageCircle,
              emptyTitle: 'ما في محادثات بعد',
              emptyMessage: 'أول ما تطلب عرض من مزود، تبدأ محادثتكم هنا.',
            )
          else
            JourneyBox(
              padding: EdgeInsets.zero,
              child: JourneyList(
                children: [
                  for (final conversation in chat.conversations)
                    _ConversationRow(
                      key: ValueKey('conversation-${conversation.id}'),
                      conversation: conversation,
                      icon:
                          widget.iconFor?.call(
                            conversation.latestQuoteRequest?.service?.title,
                          ) ??
                          LucideIcons.store,
                      when: _whenLabel(
                        conversation.lastMessage?.createdAt ??
                            conversation.lastActivityAt,
                        now,
                      ),
                      onTap: () =>
                          context.push(AppRouter.conversation(conversation.id)),
                    ),
                ],
              ),
            ),
          if (chat.canLoadMoreConversations)
            Center(
              child: JourneyTextAction(
                label: 'اعرض أكثر',
                icon: LucideIcons.chevronDown,
                color: context.accent.primary,
                onPressed: chat.isLoadingMoreConversations
                    ? null
                    : chat.loadMoreConversations,
              ),
            ),
        ],
      ),
    );
    if (widget.embedded) return content;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: content,
    );
  }
}

/// «10:40» today, «أمس», the weekday within a week, else «12 أكتوبر».
String _whenLabel(DateTime at, DateTime now) {
  final local = at.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days <= 0) {
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  if (days == 1) return 'أمس';
  if (days < 7) return formatArabicWeekday(local);
  return formatArabicDayMonth(local);
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.icon,
    required this.when,
    required this.onTap,
    super.key,
  });

  final ChatConversation conversation;
  final IconData icon;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadMessageCount;
    final service = conversation.latestQuoteRequest?.service?.title.trim();
    final name = conversation.counterpartName;
    final last = !conversation.providerJoined
        ? 'المزود ما دخل المحادثة بعد'
        : conversation.lastMessage?.body.trim().isNotEmpty == true
        ? conversation.lastMessage!.body.trim()
        : service != null && service.isNotEmpty
        ? '${conversation.viewerIsProvider ? 'طلب' : 'طلبت'}: $service'
        : 'ما في رسائل بعد';
    return AarastPressable(
      onTap: onTap,
      semanticLabel: [
        name,
        last,
        if (unread > 0) '$unread غير مقروءة',
      ].join('، '),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            JourneyIconTile(
              icon: icon,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  Text(
                    last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: unread > 0 ? JourneyType.bold : FontWeight.w400,
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  when,
                  style: JourneyType.of(
                    JourneyType.caption,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                if (unread > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.accent.primary,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Text(
                      '$unread',
                      style: JourneyType.of(
                        JourneyType.caption,
                        weight: JourneyType.bold,
                        color: AarastV3Color.onPrimary,
                      ),
                    ),
                  )
                else if (conversation.muted)
                  const Icon(
                    LucideIcons.bellOff,
                    size: 16,
                    color: AarastV3Color.textMuted,
                    semanticLabel: 'مكتومة',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
