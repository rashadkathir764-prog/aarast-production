import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/media/media_upload_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  MediaUploadTicket? _attachment;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ChatProvider>().openConversation(
        widget.conversationId,
      );
      _scrollToEnd();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final conversation = _conversation(chat);
    final messages = chat.messagesFor(widget.conversationId);
    return AarastScreenFrame(
      resizeToAvoidBottomInset: true,
      child: Column(
        children: [
          _ChatHeader(
            conversation: conversation,
            onAction: (action) => _handleAction(chat, conversation, action),
          ),
          Expanded(
            child: chat.isLoading && messages.isEmpty
                ? const AarastScreenLoading(label: 'جارٍ تحميل الرسائل...')
                : chat.errorMessage != null && messages.isEmpty
                ? AarastErrorState(
                    title: 'تعذر تحميل المحادثة',
                    message: chat.errorMessage!,
                    onRetry: () => chat.openConversation(widget.conversationId),
                  )
                : messages.isEmpty
                ? const AarastEmptyState(
                    icon: LucideIcons.messageCircle,
                    title: 'ابدأ المحادثة',
                    message:
                        'ناقشا تفاصيل طلب السعر دون مشاركة بيانات مالية خاصة.',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return _MessageBubble(
                        message: message,
                        mine: message.senderUserId == chat.currentUserId,
                      );
                    },
                  ),
          ),
          if (conversation?.blocked == true)
            const _BlockedNotice()
          else
            _Composer(
              controller: _controller,
              attachment: _attachment,
              isBusy: chat.isSending || _isUploading,
              onPickImage: _pickImage,
              onRemoveAttachment: () => setState(() => _attachment = null),
              onSend: _send,
            ),
        ],
      ),
    );
  }

  ChatConversation? _conversation(ChatProvider provider) {
    for (final item in provider.conversations) {
      if (item.id == widget.conversationId) return item;
    }
    return null;
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (file == null || !mounted) return;
    setState(() => _isUploading = true);
    try {
      final ticket = await context.read<MediaUploadApi>().uploadImage(
        file: file,
        purpose: 'chat-image',
      );
      if (mounted) setState(() => _attachment = ticket);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر رفع الصورة الآن.')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    final attachment = _attachment;
    if (body.isEmpty && attachment == null) return;
    final ok = await context.read<ChatProvider>().send(
      widget.conversationId,
      body.isEmpty ? 'صورة' : body,
      attachments: attachment == null ? const [] : [attachment],
    );
    if (!mounted || !ok) return;
    _controller.clear();
    setState(() => _attachment = null);
    _scrollToEnd();
  }

  Future<void> _handleAction(
    ChatProvider chat,
    ChatConversation? conversation,
    String action,
  ) async {
    if (conversation == null) return;
    if (action == 'mute') {
      await chat.setMuted(conversation, !conversation.muted);
    } else if (action == 'block') {
      await chat.setBlocked(conversation, !conversation.blocked);
    } else if (action == 'report' && mounted) {
      final reason = await _reportReason(context);
      if (reason != null) await chat.report(conversation, reason);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.conversation, required this.onAction});

  final ChatConversation? conversation;
  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'رجوع',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(LucideIcons.arrowRight),
            ),
            CircleAvatar(
              backgroundColor: AppTheme.burgundySoft,
              backgroundImage: conversation?.counterpart.avatarUrl == null
                  ? null
                  : NetworkImage(conversation!.counterpart.avatarUrl!),
              child: conversation?.counterpart.avatarUrl == null
                  ? const Icon(LucideIcons.store, color: AppTheme.burgundy)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation?.counterpart.name ?? 'المحادثة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    conversation?.serviceTitle ?? 'طلب عرض سعر',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.moreVertical),
              onSelected: onAction,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'mute',
                  child: Text(
                    conversation?.muted == true
                        ? 'إلغاء الكتم'
                        : 'كتم الإشعارات',
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Text(
                    conversation?.blocked == true
                        ? 'إلغاء الحظر'
                        : 'حظر المحادثة',
                  ),
                ),
                const PopupMenuItem(value: 'report', child: Text('إبلاغ')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? AppTheme.burgundy : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final attachment in message.attachments) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Image.network(
                  attachment.url,
                  width: 250,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 80,
                    child: Center(child: Icon(LucideIcons.imageOff)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message.body,
              style: TextStyle(
                color: mine ? Colors.white : AppTheme.ink,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message.pending) ...[
              const SizedBox(height: 5),
              Text(
                'جارٍ الإرسال...',
                style: TextStyle(
                  color: mine ? Colors.white70 : AppTheme.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.attachment,
    required this.isBusy,
    required this.onPickImage,
    required this.onRemoveAttachment,
    required this.onSend,
  });

  final TextEditingController controller;
  final MediaUploadTicket? attachment;
  final bool isBusy;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Column(
          children: [
            if (attachment != null)
              Row(
                children: [
                  const Icon(LucideIcons.image, color: AppTheme.gold),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('الصورة جاهزة للإرسال')),
                  IconButton(
                    tooltip: 'إزالة الصورة',
                    onPressed: onRemoveAttachment,
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
            Row(
              children: [
                IconButton(
                  tooltip: 'إضافة صورة',
                  onPressed: isBusy ? null : onPickImage,
                  icon: const Icon(LucideIcons.imagePlus),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالتك...',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'إرسال',
                  onPressed: isBusy ? null : onSend,
                  icon: isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedNotice extends StatelessWidget {
  const _BlockedNotice();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'المحادثة محظورة. ألغِ الحظر من القائمة للمتابعة.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

Future<String?> _reportReason(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('إبلاغ عن المحادثة'),
      content: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 5,
        maxLength: 500,
        decoration: const InputDecoration(hintText: 'اكتب سبب الإبلاغ'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.length >= 3) Navigator.pop(context, value);
          },
          child: const Text('إرسال البلاغ'),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}
