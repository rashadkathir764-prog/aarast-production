import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/offer_ends.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/chat_api.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';

/// Reads the line under the provider's name, «يرد عادة خلال ساعتين»; the
/// providers side supplies it so chat keeps no copy of provider pages.
typedef ChatProviderLine =
    Future<String?> Function(BuildContext context, String providerId);

/// What the provider's portal draws around one of his conversations (p34):
/// the line under the customer's name, the strip about his offer, and the
/// fixed quick replies. Chat keeps no copy of the provider's pages, so his
/// portal supplies them; the customer's side never uses them.
class ChatProviderCase {
  const ChatProviderCase({
    required this.subtitle,
    required this.strip,
    required this.replies,
  });

  final String? Function(BuildContext context, ChatConversation conversation)
  subtitle;
  final Widget? Function(BuildContext context, ChatConversation conversation)
  strip;
  final List<ChatQuickReply> Function(
    BuildContext context,
    ChatConversation conversation,
  )
  replies;
}

/// One fixed quick reply under the messages: it sends [message] as his
/// message, or runs [onTap] (as «أعدّل العرض» opens the offer).
class ChatQuickReply {
  const ChatQuickReply({
    required this.label,
    this.message,
    this.onTap,
    this.key,
  });

  final String label;
  final String? message;
  final VoidCallback? onTap;
  final Key? key;
}

/// f06: one conversation with a provider. The request opens it as the
/// customer's own message, an offer arrives as a card to accept or compare,
/// and the name on top opens the conversation's options (w32).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.conversationId,
    this.returnQuoteToMarketplace = false,
    this.providerLine,
    this.providerCase,
    this.now,
    super.key,
  });

  final String conversationId;
  final bool returnQuoteToMarketplace;
  final ChatProviderLine? providerLine;

  /// The provider's own parts of p34; read only when he is the viewer.
  final ChatProviderCase? providerCase;

  /// Fixed in tests so «ينتهي بعد 6 أيام» does not drift.
  final DateTime? now;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  MediaUploadTicket? _attachment;
  bool _isUploading = false;
  bool _quoteNavigationInFlight = false;
  ChatProvider? _chatProvider;
  String? _lineProviderId;
  String? _providerLine;

  /// Until the first load ends an empty timeline is not yet known to be
  /// empty, so the screen keeps showing that it loads.
  bool _firstLoadDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The chat store is per plan: opening the app straight on this page
    // swaps it once the plan is chosen, and the new one starts empty, so
    // the conversation is opened again on whichever store is current.
    final chat = context.read<ChatProvider>();
    if (identical(chat, _chatProvider)) return;
    _chatProvider?.closeConversation(widget.conversationId);
    _chatProvider = chat;
    _firstLoadDone = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _open(chat));
  }

  Future<void> _open(ChatProvider chat) async {
    if (!mounted || !identical(chat, _chatProvider)) return;
    await chat.openConversation(widget.conversationId);
    if (!mounted || !identical(chat, _chatProvider)) return;
    setState(() => _firstLoadDone = true);
    _scrollToEnd();
  }

  @override
  void dispose() {
    _chatProvider?.closeConversation(widget.conversationId);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Asks once per provider for the line under the name. The provider reads
  /// the customer's name on top, so no line about himself goes under it.
  void _loadProviderLine(ChatConversation? conversation) {
    final read = widget.providerLine;
    final providerId = conversation?.provider.id ?? '';
    if (read == null ||
        conversation == null ||
        conversation.viewerIsProvider ||
        providerId.isEmpty ||
        providerId == _lineProviderId) {
      return;
    }
    _lineProviderId = providerId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final line = await read(context, providerId);
      if (mounted && _lineProviderId == providerId) {
        setState(() => _providerLine = line);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final conversation = _conversation(chat);
    _loadProviderLine(conversation);
    final timeline = chat.timelineFor(widget.conversationId);
    final requests = chat.quoteRequestsFor(widget.conversationId);
    final customerSide = !(conversation?.viewerIsProvider ?? false);
    final now = widget.now ?? DateTime.now();
    final hasOlder = chat.canLoadOlder(widget.conversationId);
    // The provider's side is drawn in his teal (p34); the customer's keeps
    // the providers section's cobalt (f06).
    final accent = customerSide ? AarastV3Color.cobalt : AarastV3Color.primary;
    final providerCase = customerSide || conversation == null
        ? null
        : widget.providerCase;
    final strip = providerCase?.strip(context, conversation!);
    final replies = providerCase == null || conversation?.canSend != true
        ? const <ChatQuickReply>[]
        : providerCase.replies(context, conversation!);

    final Widget body;
    if ((chat.isLoading || !_firstLoadDone) &&
        timeline.isEmpty &&
        !chat.hasConversationLoadError(widget.conversationId)) {
      body = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.providers,
        ),
      );
    } else if (chat.hasConversationLoadError(widget.conversationId) &&
        timeline.isEmpty) {
      body = JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.providers,
        onRetry: () => chat.openConversation(widget.conversationId),
      );
    } else if (timeline.isEmpty) {
      body = const JourneyListState(
        phase: JourneyListPhase.empty,
        section: JourneySection.providers,
        emptyIcon: LucideIcons.messageCircle,
        emptyTitle: 'ما في رسائل بعد',
      );
    } else {
      body = ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount:
            timeline.length + (hasOlder ? 1 : 0) + (replies.isEmpty ? 0 : 1),
        itemBuilder: (context, index) {
          if (replies.isNotEmpty &&
              index == timeline.length + (hasOlder ? 1 : 0)) {
            return _QuickReplies(replies: replies, onSend: _sendReply);
          }
          if (hasOlder && index == 0) {
            final loading = chat.isLoadingOlder(widget.conversationId);
            return Center(
              child: JourneyTextAction(
                key: const Key('chat-load-older'),
                label: 'رسائل أقدم',
                icon: LucideIcons.chevronUp,
                color: accent,
                onPressed: loading ? null : _loadOlder,
              ),
            );
          }
          final item = timeline[index - (hasOlder ? 1 : 0)];
          final message = item.message;
          if (message != null) {
            return _Bubble(
              mine: message.senderUserId == chat.currentUserId,
              providerSide: !customerSide,
              text: message.body,
              time: message.pending ? 'يرسل…' : _clock(message.createdAt),
              attachments: [
                for (final attachment in message.attachments)
                  _PrivateChatImage(
                    conversationId: message.conversationId,
                    attachment: attachment,
                  ),
              ],
            );
          }
          final event = item.event;
          if (event == null) return const SizedBox.shrink();
          return _EventView(
            event: event,
            request: _requestOf(requests, event.quoteRequestId),
            customerSide: customerSide,
            now: now,
            onOpenQuote: event.quoteRequestId == null
                ? null
                : () => _openQuoteEvent(conversation, event.quoteRequestId!),
          );
        },
      );
    }

    return AarastScreenFrame(
      maxWidth: 520,
      resizeToAvoidBottomInset: true,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: JourneySubHeader(
              title: conversation?.counterpartName ?? '',
              subtitle: customerSide
                  ? _providerLine
                  : providerCase?.subtitle(context, conversation!),
              onBack: () {
                if (context.canPop()) context.pop();
              },
              onTitleTap: conversation == null
                  ? null
                  : () => _openOptions(conversation),
              titleTapLabel: 'خيارات المحادثة',
            ),
          ),
          if (strip != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: strip,
            ),
          Expanded(child: body),
          if (conversation?.blocked == true)
            _Notice(
              text: conversation?.blockedByMe == true
                  ? 'حظرته. ترفع الحظر من اسمه فوق.'
                  : 'ما تقدر ترسل في هذي المحادثة الحين.',
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            )
          else if (conversation?.providerJoined == false)
            const _Notice(
              text: 'ما يقدر يرد لين يستلم صاحبه ملفه.',
              color: AarastV3Color.amber,
              soft: AarastV3Color.amberSoft,
            )
          else if (conversation?.canSend == true)
            _Composer(
              providerSide: !customerSide,
              controller: _controller,
              attachment: _attachment,
              isBusy: chat.isSending || _isUploading,
              onPickImage: _pickImage,
              onRemoveAttachment: () => setState(() => _attachment = null),
              onSend: _send,
            )
          else if (conversation != null)
            const _Notice(
              text: 'ما تقدر ترسل في هذي المحادثة الحين.',
              color: AarastV3Color.textMuted,
              soft: AarastV3Color.line,
            ),
        ],
      ),
    );
  }

  ChatQuoteRequestSummary? _requestOf(
    List<ChatQuoteRequestSummary> requests,
    String? id,
  ) {
    if (id == null) return null;
    for (final request in requests) {
      if (request.id == id) return request;
    }
    return null;
  }

  Future<void> _openQuoteEvent(
    ChatConversation? conversation,
    String quoteRequestId,
  ) async {
    if (_quoteNavigationInFlight) return;
    // The provider answers a request from his portal's requests tab; the
    // plan's providers and the marketplace belong to the customer.
    if (conversation?.viewerIsProvider ?? false) {
      context.go(AppRouter.providerRequestsTab);
      return;
    }
    _quoteNavigationInFlight = true;
    if (widget.returnQuoteToMarketplace && context.canPop()) {
      context.pop(ProviderMarketplaceRouteResult.focusQuote(quoteRequestId));
      return;
    }
    final planId = conversation?.weddingPlan?.id;
    try {
      if (planId != null && planId.isNotEmpty) {
        await context.push(
          AppRouter.planProviders(planId, quoteId: quoteRequestId),
        );
        return;
      }
      await context.push(
        '${AppRouter.providerMarketplace}?quoteId=${Uri.encodeQueryComponent(quoteRequestId)}',
      );
    } finally {
      if (mounted) _quoteNavigationInFlight = false;
    }
  }

  ChatConversation? _conversation(ChatProvider provider) {
    for (final item in provider.conversations) {
      if (item.id == widget.conversationId) return item;
    }
    return null;
  }

  /// w32: mute, report, block.
  Future<void> _openOptions(ChatConversation conversation) async {
    final action = await showJourneySheet<String>(
      context: context,
      builder: (_) => _OptionsSheet(conversationId: conversation.id),
    );
    if (!mounted || action == null) return;
    final chat = context.read<ChatProvider>();
    if (action == 'block') {
      final ok = await chat.setBlocked(conversation, !conversation.blockedByMe);
      if (mounted && !ok) _showError(chat.errorMessage);
      return;
    }
    if (action == 'report') {
      final reason = await showJourneySheet<String>(
        context: context,
        builder: (_) => const _ReportSheet(),
      );
      if (!mounted || reason == null) return;
      final ok = await chat.report(conversation, reason);
      if (!mounted) return;
      if (ok) {
        AarastToast.showSuccess(context, 'وصلنا بلاغك، بنراجعه.');
      } else {
        _showError(chat.errorMessage);
      }
    }
  }

  void _showError(String? message) {
    if (message != null) AarastToast.showError(context, message);
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
        AarastToast.showError(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        AarastToast.showError(context, 'ما قدرنا نرفع الصورة، جرب مرة ثانية.');
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
      _showError(context.read<ChatProvider>().errorMessage);
      return;
    }
    _controller.clear();
    setState(() => _attachment = null);
    _scrollToEnd();
  }

  /// A quick reply goes as his own message, as if typed.
  Future<void> _sendReply(String text) async {
    final chat = context.read<ChatProvider>();
    final ok = await chat.send(widget.conversationId, text);
    if (!mounted) return;
    if (!ok) {
      _showError(chat.errorMessage);
      return;
    }
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

/// «10:12».
String _clock(DateTime at) {
  final local = at.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// The customer's own messages sit on the reading side in cobalt (f06); the
/// provider's sit on the far side in teal (p34). Theirs are white.
class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.mine,
    required this.text,
    required this.time,
    this.providerSide = false,
    this.attachments = const [],
    super.key,
  });

  final bool mine;
  final bool providerSide;
  final String text;
  final String time;
  final List<Widget> attachments;

  @override
  Widget build(BuildContext context) {
    final ink = mine ? AarastV3Color.onPrimary : AarastV3Color.text;
    final onReadingSide = providerSide ? !mine : mine;
    return Align(
      alignment: onReadingSide
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: providerSide ? 270 : 290),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine
              ? (providerSide ? AarastV3Color.primary : AarastV3Color.cobalt)
              : AarastV3Color.paper,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final attachment in attachments) ...[
              attachment,
              const SizedBox(height: 8),
            ],
            Text(text, style: JourneyType.of(JourneyType.body, color: ink)),
            Text(
              time,
              style: JourneyType.of(
                JourneyType.caption,
                color: mine
                    ? AarastV3Color.onPrimaryMuted
                    : AarastV3Color.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quote event in the conversation: the request as the customer's message,
/// an offer as its card, anything else as one quiet line.
class _EventView extends StatelessWidget {
  const _EventView({
    required this.event,
    required this.request,
    required this.customerSide,
    required this.now,
    required this.onOpenQuote,
  });

  final ChatConversationEvent event;
  final ChatQuoteRequestSummary? request;
  final bool customerSide;
  final DateTime now;
  final VoidCallback? onOpenQuote;

  @override
  Widget build(BuildContext context) {
    final key = Key('conversation-event-${event.type.toLowerCase()}');
    switch (event.type) {
      case 'QUOTE_REQUEST_CREATED':
        final service = request?.service?.title;
        final message = request?.message?.trim() ?? '';
        final asked = customerSide ? 'طلبت' : 'طلب';
        return _Bubble(
          key: key,
          mine: customerSide,
          providerSide: !customerSide,
          text: message.isNotEmpty
              ? message
              : service == null
              ? '$asked عرض سعر'
              : '$asked عرض: $service',
          time: _clock(event.occurredAt),
        );
      // The provider reads his own offer in the strip on top (p34), so on
      // his side the event is one quiet line.
      case 'QUOTE_OFFER_RECEIVED' when customerSide:
        return _OfferCard(
          key: key,
          offer: _offer,
          serviceTitle: request?.service?.title,
          customerSide: customerSide,
          now: now,
          onOpen: onOpenQuote,
        );
    }
    final label = switch (event.type) {
      'QUOTE_OFFER_RECEIVED' => 'أرسلت عرضك',
      'QUOTE_REQUEST_CANCELLED' => 'تسكّر الطلب',
      'QUOTE_REQUEST_REJECTED' =>
        customerSide ? 'اعتذروا عن الطلب' : 'اعتذرت عن الطلب',
      'QUOTE_OFFER_REJECTED' => 'انرفض العرض',
      'QUOTE_OFFER_ACCEPTED' => 'انقبل العرض',
      'QUOTE_OFFER_EXPIRED' => 'انتهت مدة العرض',
      _ => 'تغيّر شي في الطلب',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: AarastPressable(
          key: key,
          onTap: onOpenQuote,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '$label · ${_clock(event.occurredAt)}',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  ChatQuoteOffer? get _offer {
    final offers = request?.offers ?? const <ChatQuoteOffer>[];
    for (final offer in offers) {
      if (offer.id == event.quoteOfferId) return offer;
    }
    return null;
  }
}

/// f06's offer card: what it is, its price and what comes with it, and the
/// two ways forward. Accepting happens on the offer itself, where it is
/// confirmed, so both buttons open it.
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.serviceTitle,
    required this.customerSide,
    required this.now,
    required this.onOpen,
    super.key,
  });

  final ChatQuoteOffer? offer;
  final String? serviceTitle;
  final bool customerSide;
  final DateTime now;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final offer = this.offer;
    final validUntil = offer?.validUntil;
    final ends = validUntil == null ? null : offerEndsLabel(validUntil, now);
    final status = offer?.status ?? 'PENDING';
    final expired = validUntil != null && ends == null;
    final open = status == 'PENDING' && !expired;
    final (tag, tagColor, tagSoft) = switch (status) {
      'ACCEPTED' => ('انقبل', AarastV3Color.mint, AarastV3Color.mintSoft),
      'REJECTED' => ('انرفض', AarastV3Color.textMuted, AarastV3Color.line),
      'WITHDRAWN' => ('سحبوه', AarastV3Color.textMuted, AarastV3Color.line),
      _ when expired => (
        'انتهت مدته',
        AarastV3Color.textMuted,
        AarastV3Color.line,
      ),
      _ when customerSide => (
        'وصلك عرض',
        AarastV3Color.cobalt,
        AarastV3Color.cobaltSoft,
      ),
      _ => ('عرضك', AarastV3Color.cobalt, AarastV3Color.cobaltSoft),
    };
    final title = offer?.title?.trim().isNotEmpty == true
        ? offer!.title!.trim()
        : serviceTitle;
    final price = _money(offer?.amount, offer?.currency);
    final headline = [?title, ?price].join(' · ');
    final details = offer?.message?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AarastPressable(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: JourneyBox(
          padding: const EdgeInsets.all(14),
          borderColor: open ? AarastV3Color.cobalt : AarastV3Color.line,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  JourneyTag(label: tag, color: tagColor, soft: tagSoft),
                  const Spacer(),
                  if (open && ends != null)
                    Text(
                      ends,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                ],
              ),
              if (headline.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  headline,
                  style: JourneyType.of(
                    JourneyType.title,
                    weight: JourneyType.bold,
                  ),
                ),
              ],
              if (details.isNotEmpty)
                Text(
                  details,
                  style: JourneyType.of(
                    JourneyType.body,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              if (open && customerSide && onOpen != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: JourneyButton(
                        key: const Key('chat-offer-accept'),
                        label: 'اقبل العرض',
                        background: AarastV3Color.cobalt,
                        expand: true,
                        onPressed: onOpen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: JourneyButton(
                        key: const Key('chat-offer-compare'),
                        label: 'قارن',
                        background: AarastV3Color.cobaltSoft,
                        foreground: AarastV3Color.cobalt,
                        expand: true,
                        onPressed: onOpen,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// «550,000 ر.ي»; null when the amount is hidden or unreadable.
String? _money(String? amount, String? currency) {
  final value = num.tryParse(amount?.replaceAll(',', '').trim() ?? '');
  if (value == null) return null;
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer ${currencyLabelAr(currency)}';
}

/// w32: the conversation's options. Muting applies at once; reporting and
/// blocking close the sheet and carry on in the screen.
class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    ChatConversation? conversation;
    for (final item in chat.conversations) {
      if (item.id == conversationId) conversation = item;
    }
    if (conversation == null) return const SizedBox.shrink();
    final current = conversation;
    final provider = current.viewerIsProvider;
    return JourneySheetBody(
      title: current.counterpartName,
      children: [
        JourneyList(
          children: [
            JourneyListRow(
              key: const Key('chat-option-mute'),
              icon: LucideIcons.bellOff,
              color: AarastV3Color.ink,
              soft: AarastV3Color.canvas,
              title: 'كتم المحادثة',
              subtitle: 'الرسائل توصل بدون تنبيه',
              trailing: JourneyToggle(
                value: current.muted,
                color: AarastV3Color.cobalt,
                onChanged: (value) async {
                  final ok = await chat.setMuted(current, value);
                  if (!ok && context.mounted) {
                    final message = chat.errorMessage;
                    if (message != null) {
                      AarastToast.showError(context, message);
                    }
                  }
                },
              ),
            ),
            JourneyListRow(
              key: const Key('chat-option-report'),
              icon: LucideIcons.flag,
              color: AarastV3Color.amber,
              soft: AarastV3Color.amberSoft,
              title: 'بلّغ عن مشكلة',
              subtitle: 'تأخير، كلام غير لائق، احتيال',
              onTap: () => Navigator.of(context).pop('report'),
            ),
            JourneyListRow(
              key: const Key('chat-option-block'),
              icon: LucideIcons.ban,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
              title: current.blockedByMe
                  ? 'ارفع الحظر'
                  : provider
                  ? 'احظر العميل'
                  : 'احظر المزود',
              subtitle: current.blockedByMe
                  ? 'يقدر يراسلك من جديد'
                  : 'ما يقدر يراسلك',
              onTap: () => Navigator.of(context).pop('block'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        JourneyNote(
          text: provider
              ? 'الحظر ما يلغي حجز العميل المؤكد. ألغه من "حجوزاتك" في الرئيسية لو تشتي.'
              : 'الحظر ما يلغي الحجز المؤكد. ألغه من "الحجوزات" لو تشتي.',
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
        ),
      ],
    );
  }
}

/// The report's reason, from the three w32 names under «بلّغ عن مشكلة».
class _ReportSheet extends StatelessWidget {
  const _ReportSheet();

  static const _reasons = ['تأخير', 'كلام غير لائق', 'احتيال'];

  @override
  Widget build(BuildContext context) {
    return JourneySheetBody(
      title: 'ايش المشكلة؟',
      children: [
        for (final reason in _reasons) ...[
          JourneyChoiceCard(
            key: Key('chat-report-$reason'),
            title: reason,
            subtitle: '',
            leading: const SizedBox.shrink(),
            selected: false,
            onTap: () => Navigator.of(context).pop(reason),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color, required this.soft});

  final String text;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: JourneyNote(text: text, color: color, soft: soft),
    );
  }
}

/// The fixed quick replies under the messages (p34): chips that send a line
/// or open a page.
class _QuickReplies extends StatelessWidget {
  const _QuickReplies({required this.replies, required this.onSend});

  final List<ChatQuickReply> replies;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final reply in replies)
            JourneyChip(
              key: reply.key,
              label: reply.label,
              onTap:
                  reply.onTap ??
                  (reply.message == null ? null : () => onSend(reply.message!)),
            ),
        ],
      ),
    );
  }
}

/// The white field and the round send button. On the provider's side it is
/// p34's one white bar holding the field, the picture button and a 38-point
/// send circle in his teal.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.providerSide,
    required this.controller,
    required this.attachment,
    required this.isBusy,
    required this.onPickImage,
    required this.onRemoveAttachment,
    required this.onSend,
  });

  final bool providerSide;
  final TextEditingController controller;
  final MediaUploadTicket? attachment;
  final bool isBusy;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onSend;

  Color get _accent =>
      providerSide ? AarastV3Color.primary : AarastV3Color.cobalt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: providerSide
          ? const EdgeInsets.fromLTRB(16, 6, 16, 12)
          : const EdgeInsets.fromLTRB(14, 6, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (attachment != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(LucideIcons.image, size: 18, color: _accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الصورة جاهزة',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                  JourneyRoundButton(
                    icon: LucideIcons.x,
                    tooltip: 'شيل الصورة',
                    size: 36,
                    onPressed: onRemoveAttachment,
                  ),
                ],
              ),
            ),
          if (providerSide) _drawnBar() else _fieldAndSend(),
        ],
      ),
    );
  }

  Widget _imageButton() => Semantics(
    button: true,
    label: 'أرسل صورة',
    child: AarastPressable(
      onTap: isBusy ? null : onPickImage,
      borderRadius: BorderRadius.circular(20),
      child: Icon(
        LucideIcons.image,
        size: providerSide ? 22 : 20,
        color: providerSide ? _accent : AarastV3Color.textFaint,
      ),
    ),
  );

  Widget _sendButton(double size, double icon) => Semantics(
    button: true,
    label: 'أرسل',
    child: AarastPressable(
      onTap: isBusy ? null : onSend,
      borderRadius: BorderRadius.circular(size / 2),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
        child: isBusy
            ? const Center(
                child: AarastInlineSpinner(color: AarastV3Color.onPrimary),
              )
            : Icon(
                LucideIcons.send,
                size: icon,
                color: AarastV3Color.onPrimary,
              ),
      ),
    ),
  );

  /// p34: one white bar with a hairline, the field, the picture button and
  /// the send circle inside it.
  Widget _drawnBar() {
    return Container(
      key: const Key('chat-composer-bar'),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AarastV3Color.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              style: JourneyType.of(JourneyType.body),
              cursorColor: _accent,
              decoration: InputDecoration(
                hintText: 'اكتب رسالة…',
                hintStyle: JourneyType.of(
                  JourneyType.body,
                  color: AarastV3Color.textFaint,
                ),
                counterText: '',
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _imageButton(),
          const SizedBox(width: 10),
          _sendButton(38, 18),
        ],
      ),
    );
  }

  Widget _fieldAndSend() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            maxLength: 2000,
            style: JourneyType.of(JourneyType.body),
            decoration: InputDecoration(
              hintText: 'اكتب رسالتك...',
              hintStyle: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textFaint,
              ),
              counterText: '',
              filled: true,
              fillColor: AarastV3Color.paper,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: _accent, width: 2),
              ),
              suffixIcon: _imageButton(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _sendButton(46, 19),
      ],
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
      borderRadius: BorderRadius.circular(14),
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
