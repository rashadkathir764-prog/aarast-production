import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

class QuoteConversationEntryScreen extends StatefulWidget {
  const QuoteConversationEntryScreen({
    required this.quoteRequestId,
    this.returnQuoteToMarketplace = false,
    this.providerLine,
    this.providerCase,
    super.key,
  });

  final String quoteRequestId;
  final bool returnQuoteToMarketplace;
  final ChatProviderLine? providerLine;
  final ChatProviderCase? providerCase;

  @override
  State<QuoteConversationEntryScreen> createState() =>
      _QuoteConversationEntryScreenState();
}

class _QuoteConversationEntryScreenState
    extends State<QuoteConversationEntryScreen> {
  ChatConversation? _conversation;
  String? _error;

  /// The request is gone or is not this account's (RA-MO-250): the page
  /// offered «retry», which could never succeed.
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (mounted) {
      setState(() {
        _error = null;
        _gone = false;
      });
    }
    try {
      final chat = context.read<ChatProvider>();
      final conversation = await chat.openQuote(widget.quoteRequestId);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _gone = conversation == null && chat.quoteOpenRefused;
        _error = conversation == null
            ? (chat.errorMessage ?? aarastBackendConnectionErrorMessage)
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = aarastBackendConnectionErrorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _conversation;
    if (conversation != null) {
      return ChatScreen(
        conversationId: conversation.id,
        returnQuoteToMarketplace: widget.returnQuoteToMarketplace,
        providerLine: widget.providerLine,
        providerCase: widget.providerCase,
      );
    }
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
        children: [
          const JourneySubHeader(title: ''),
          if (_gone)
            const JourneyListState(
              key: ValueKey('quote-conversation-gone'),
              phase: JourneyListPhase.empty,
              section: JourneySection.providers,
              emptyIcon: LucideIcons.messageCircle,
              emptyTitle: 'هذي المحادثة ما عادت مفتوحة',
              emptyMessage: 'الطلب انشال، أو هو لخطة ثانية غير المفتوحة الآن.',
            )
          else
            JourneyListState(
              phase: _error == null
                  ? JourneyListPhase.loading
                  : JourneyListPhase.error,
              section: JourneySection.providers,
              onRetry: _open,
            ),
        ],
      ),
    );
  }
}
