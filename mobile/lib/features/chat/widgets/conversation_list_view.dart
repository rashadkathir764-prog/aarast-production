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
      color: AppTheme.burgundy,
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
              subtitle: 'محادثات مرتبطة بطلبات أسعار حقيقية فقط.',
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
              message: 'تبدأ المحادثة من طلب سعر لحماية المستخدم والمزوّد.',
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
              backgroundColor: AppTheme.burgundySoft,
              backgroundImage: conversation.counterpart.avatarUrl == null
                  ? null
                  : NetworkImage(conversation.counterpart.avatarUrl!),
              child: conversation.counterpart.avatarUrl == null
                  ? const Icon(LucideIcons.store, color: AppTheme.burgundy)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.counterpart.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage?.body ??
                        conversation.serviceTitle ??
                        'طلب عرض سعر',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (conversation.unreadCount > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                height: 24,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: const BoxDecoration(
                  color: AppTheme.burgundy,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              )
            else
              const Icon(LucideIcons.chevronLeft, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}
