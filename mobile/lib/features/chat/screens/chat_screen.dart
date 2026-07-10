import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/chat_api.dart';
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
  ChatProvider? _chatProvider;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider ??= context.read<ChatProvider>();
  }

  @override
  void dispose() {
    _chatProvider?.closeConversation(widget.conversationId);
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
                : chat.hasConversationLoadError(widget.conversationId) &&
                      messages.isEmpty
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
                    itemCount:
                        messages.length +
                        (chat.canLoadOlder(widget.conversationId) ? 1 : 0),
                    itemBuilder: (context, index) {
                      final hasOlder = chat.canLoadOlder(widget.conversationId);
                      if (hasOlder && index == 0) {
                        return Center(
                          child: TextButton.icon(
                            key: const Key('chat-load-older'),
                            onPressed:
                                chat.isLoadingOlder(widget.conversationId)
                                ? null
                                : _loadOlder,
                            icon: chat.isLoadingOlder(widget.conversationId)
                                ? const AarastInlineSpinner(dimension: 16)
                                : const Icon(LucideIcons.history, size: 18),
                            label: const Text('تحميل رسائل أقدم'),
                          ),
                        );
                      }
                      final message = messages[index - (hasOlder ? 1 : 0)];
                      return _MessageBubble(
                        message: message,
                        mine: message.senderUserId == chat.currentUserId,
                        read: chat.isMessageRead(message),
                      );
                    },
                  ),
          ),
          if (conversation?.blocked == true)
            _BlockedNotice(
              blockedByMe: conversation?.blockedByMe == true,
              blockedByCounterpart: conversation?.blockedByCounterpart == true,
            )
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
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
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
    if (!mounted) return;
    if (!ok) {
      final message = context.read<ChatProvider>().errorMessage;
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    _controller.clear();
    setState(() => _attachment = null);
    _scrollToEnd();
  }

  Future<void> _loadOlder() async {
    final previousMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    await context.read<ChatProvider>().loadOlder(widget.conversationId);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final addedExtent =
          _scrollController.position.maxScrollExtent - previousMax;
      _scrollController.jumpTo(
        (previousOffset + addedExtent).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
      );
    });
  }

  Future<void> _handleAction(
    ChatProvider chat,
    ChatConversation? conversation,
    String action,
  ) async {
    if (conversation == null) return;
    bool? succeeded;
    String? successMessage;
    if (action == 'mute') {
      succeeded = await chat.setMuted(conversation, !conversation.muted);
    } else if (action == 'block') {
      succeeded = await chat.setBlocked(
        conversation,
        !conversation.blockedByMe,
      );
    } else if (action == 'report' && mounted) {
      final reason = await _reportReason(context);
      if (reason != null) {
        succeeded = await chat.report(conversation, reason);
        successMessage = 'تم إرسال البلاغ للمراجعة.';
      }
    }
    if (!mounted || succeeded == null) return;
    final message = succeeded ? successMessage : chat.errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
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
                    conversation?.blockedByMe == true
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
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.read,
  });

  final ChatMessage message;
  final bool mine;
  final bool read;

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
              _PrivateChatImage(
                conversationId: message.conversationId,
                attachment: attachment,
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
            ] else if (read) ...[
              const SizedBox(height: 5),
              Text(
                'تمت القراءة',
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

class _PrivateChatImage extends StatefulWidget {
  const _PrivateChatImage({
    required this.conversationId,
    required this.attachment,
  });

  final String conversationId;
  final ChatAttachment attachment;

  @override
  State<_PrivateChatImage> createState() => _PrivateChatImageState();
}

class _PrivateChatImageState extends State<_PrivateChatImage> {
  late String _url;
  DateTime? _expiresAt;
  bool _refreshing = false;
  bool _refreshAttempted = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _useAttachment(widget.attachment);
  }

  @override
  void didUpdateWidget(covariant _PrivateChatImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != widget.attachment.id ||
        oldWidget.attachment.url != widget.attachment.url) {
      _useAttachment(widget.attachment);
    }
  }

  void _useAttachment(ChatAttachment attachment) {
    _url = attachment.url;
    _expiresAt = attachment.expiresAt;
    _refreshing = false;
    _refreshAttempted = false;
    _failed = false;
  }

  bool get _isExpired =>
      _expiresAt != null &&
      !_expiresAt!.isAfter(DateTime.now().add(const Duration(seconds: 10)));

  void _scheduleRefresh() {
    if (_refreshing || _refreshAttempted) return;
    _refreshAttempted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _refreshing = true;
      _failed = false;
    });
    try {
      final access = await context.read<ChatApi>().refreshAttachment(
        widget.conversationId,
        widget.attachment.id,
      );
      if (!mounted) return;
      setState(() {
        _url = access.url;
        _expiresAt = access.expiresAt;
        _refreshing = false;
        _failed = access.url.isEmpty;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if ((_url.isEmpty || _isExpired) && !_failed) _scheduleRefresh();
    if (_refreshing || ((_url.isEmpty || _isExpired) && !_failed)) {
      return const SizedBox(
        width: 250,
        height: 180,
        child: Center(child: AarastInlineSpinner()),
      );
    }
    if (_failed || _url.isEmpty) return const _PrivateImageFailure();
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Image.network(
        _url,
        key: ValueKey(_url),
        width: 250,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          _scheduleRefresh();
          return _refreshAttempted
              ? const _PrivateImageFailure()
              : const SizedBox(
                  width: 250,
                  height: 180,
                  child: Center(child: AarastInlineSpinner()),
                );
        },
      ),
    );
  }
}

class _PrivateImageFailure extends StatelessWidget {
  const _PrivateImageFailure();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 250,
      height: 80,
      child: Center(child: Icon(LucideIcons.imageOff)),
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
                      ? const AarastInlineSpinner(color: AppTheme.surface)
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
  const _BlockedNotice({
    required this.blockedByMe,
    required this.blockedByCounterpart,
  });

  final bool blockedByMe;
  final bool blockedByCounterpart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          blockedByMe
              ? 'أنت حظرت هذه المحادثة. ألغِ الحظر من القائمة للمتابعة.'
              : blockedByCounterpart
              ? 'أوقف الطرف الآخر المحادثة. لا يمكن إرسال رسائل جديدة الآن.'
              : 'المحادثة محظورة. لا يمكن إرسال رسائل جديدة الآن.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.danger,
            fontWeight: FontWeight.w800,
          ),
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
