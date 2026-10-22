import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';

class ConversationListView extends StatefulWidget {
  const ConversationListView({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<ConversationListView> createState() => _ConversationListViewState();
}

class _ConversationListViewState extends State<ConversationListView> {
  @override
  void initState() {
    super.initState();
    if (!widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<ChatProvider>().initialize();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final content = RefreshIndicator(
      color: AppTheme.brand,
      onRefresh: chat.initialize,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          widget.embedded ? 18 : 4,
          20,
          widget.embedded ? 126 : 32,
        ),
        children: [
          if (widget.embedded) ...[
            const AarastSectionHeader(
              title: 'الرسائل',
              subtitle: 'محادثة واحدة مع كل مزود داخل الخطة.',
              icon: LucideIcons.messagesSquare,
            ),
            const SizedBox(height: 18),
          ],
          if (chat.isLoading && chat.conversations.isEmpty)
            const AarastScreenLoading(label: 'جارٍ تحميل المحادثات...')
          else if (chat.errorMessage != null && chat.conversations.isEmpty)
            AarastErrorState(
              title: 'تعذر تحميل الرسائل',
              message: chat.errorMessage!,
              onRetry: chat.initialize,
            )
          else if (chat.conversations.isEmpty)
            const AarastEmptyState(
              icon: LucideIcons.messageCircle,
              title: 'لا توجد محادثات بعد',
              message: 'تظهر المحادثة تلقائيًا عند إنشاء أول طلب سعر.',
            )
          else
            for (final conversation in chat.conversations) ...[
              _ConversationTile(
                conversation: conversation,
                onTap: () =>
                    context.push(AppRouter.conversation(conversation.id)),
              ),
              const SizedBox(height: 10),
            ],
          if (chat.canLoadMoreConversations)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AarastButton(
                label: 'عرض المزيد',
                icon: LucideIcons.chevronsDown,
                isLoading: chat.isLoadingMoreConversations,
                onPressed: chat.loadMoreConversations,
              ),
            ),
        ],
      ),
    );
    if (widget.embedded) return content;
    return AarastPageScaffold(title: 'الرسائل', showBack: true, child: content);
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final ChatConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: AarastCard(
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: AppTheme.brandMuted,
              backgroundImage: conversation.provider.logoUrl == null
                  ? null
                  : NetworkImage(conversation.provider.logoUrl!),
              child: conversation.provider.logoUrl == null
                  ? const Icon(LucideIcons.store, color: AppTheme.brand)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.provider.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _contextLabel(conversation),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    conversation.providerJoined
                        ? (conversation.lastMessage?.body ??
                              'آخر نشاط على طلبات الأسعار')
                        : 'المزود لم ينضم بعد',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: conversation.providerJoined
                          ? AppTheme.textSecondary
                          : AppTheme.focus,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (conversation.muted) ...[
              const Icon(
                LucideIcons.bellOff,
                size: 17,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
            ],
            if (conversation.unreadMessageCount > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: AppTheme.brand,
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${conversation.unreadMessageCount}',
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else
              const Icon(
                LucideIcons.chevronLeft,
                color: AppTheme.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

String _contextLabel(ChatConversation conversation) {
  final scope = conversation.scope == ChatConversationScope.plan
      ? (conversation.weddingPlan?.title ?? 'خطة الزفاف')
      : 'طلب مستقل عن الخطة';
  final count = conversation.quoteRequestCount == 1
      ? 'طلب واحد'
      : '${conversation.quoteRequestCount} طلبات';
  return '$scope · $count';
}
