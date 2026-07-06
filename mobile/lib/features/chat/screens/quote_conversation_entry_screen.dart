import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/aarast_ui.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

class QuoteConversationEntryScreen extends StatefulWidget {
  const QuoteConversationEntryScreen({required this.quoteRequestId, super.key});

  final String quoteRequestId;

  @override
  State<QuoteConversationEntryScreen> createState() =>
      _QuoteConversationEntryScreenState();
}

class _QuoteConversationEntryScreenState
    extends State<QuoteConversationEntryScreen> {
  ChatConversation? _conversation;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final chat = context.read<ChatProvider>();
    await chat.initialize();
    if (!mounted) return;
    final conversation = await chat.openQuote(widget.quoteRequestId);
    if (!mounted) return;
    setState(() {
      _conversation = conversation;
      _error = conversation == null ? chat.errorMessage : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    if (conversation != null) {
      return ChatScreen(conversationId: conversation.id);
    }
    return AarastPageScaffold(
      title: 'المحادثة',
      showBack: true,
      child: _error == null
          ? const AarastScreenLoading(label: 'جارٍ فتح المحادثة الآمنة...')
          : AarastErrorState(
              title: 'تعذر فتح المحادثة',
              message: _error!,
              onRetry: _open,
            ),
    );
  }
}
