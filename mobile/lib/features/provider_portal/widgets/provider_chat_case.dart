import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../chat/chat_api.dart'
    show ChatConversation, ChatProviderCase, ChatQuickReply;
import '../../marketplace/marketplace_api.dart' show QuoteRequest;
import '../providers/provider_dashboard_provider.dart';
import 'provider_request_parts.dart';

/// p34 «المحادثة» on the provider's side: the line under the customer's
/// name, the strip about his offer and the fixed quick replies. They are
/// read from his own request list, so a chat opened before the list is read
/// shows the messages alone.
const providerChatCase = ChatProviderCase(
  subtitle: _subtitle,
  strip: _strip,
  replies: _replies,
);

ProviderDashboardProvider? _dashboard(BuildContext context) {
  try {
    return context.watch<ProviderDashboardProvider>();
  } on ProviderNotFoundException {
    return null;
  }
}

QuoteRequest? _quoteOf(BuildContext context, ChatConversation conversation) {
  final id = conversation.latestQuoteRequest?.id;
  final dashboard = _dashboard(context);
  if (id == null || dashboard == null) return null;
  for (final quote in dashboard.quoteRequests) {
    if (quote.id == id) return quote;
  }
  return null;
}

/// «الخميس 21 يناير · صور وفيديو»: the day and what he asked for (no
/// occasion, which the server does not hold).
String? _subtitle(BuildContext context, ChatConversation conversation) {
  final quote = _quoteOf(context, conversation);
  if (quote == null) return null;
  final line = providerRequestLine(quote);
  return line.isEmpty ? null : line;
}

Widget? _strip(BuildContext context, ChatConversation conversation) {
  final dashboard = _dashboard(context);
  final quote = _quoteOf(context, conversation);
  if (dashboard == null || quote == null) return null;
  return ProviderChatStrip(
    quote: quote,
    state: providerCaseOf(quote, providerBookingOf(quote, dashboard)),
  );
}

/// The device-side quick replies (B-29 would make them his own): send an
/// offer or change it, and send the shop's place when he wrote one. The
/// drawn «الدرون 80,000 إضافة» answers one message and is not fixed.
List<ChatQuickReply> _replies(
  BuildContext context,
  ChatConversation conversation,
) {
  final dashboard = _dashboard(context);
  if (dashboard == null || !dashboard.canUseProviderOperations) {
    return const [];
  }
  final quote = _quoteOf(context, conversation);
  final address = dashboard.profile?.address?.trim() ?? '';
  final state = quote == null
      ? null
      : providerCaseOf(quote, providerBookingOf(quote, dashboard));
  return [
    if (quote != null && state == ProviderCaseState.fresh)
      ChatQuickReply(
        key: const Key('provider-chat-reply-offer'),
        label: 'أرسل عرض',
        onTap: () => context.push(AppRouter.providerRequestOffer(quote.id)),
      ),
    if (quote != null &&
        (state == ProviderCaseState.replied ||
            state == ProviderCaseState.offerExpired))
      ChatQuickReply(
        key: const Key('provider-chat-reply-edit'),
        label: 'أعدّل العرض',
        onTap: () => context.push(AppRouter.providerRequestOffer(quote.id)),
      ),
    if (address.isNotEmpty)
      ChatQuickReply(
        key: const Key('provider-chat-reply-place'),
        label: 'أرسل موقع المحل',
        message: 'موقع المحل: $address',
      ),
  ];
}

/// p34's strip: his offer, its price and the days it stays open, with the
/// request's status word; before an offer, what the customer asked for. It
/// opens the request.
class ProviderChatStrip extends StatelessWidget {
  const ProviderChatStrip({
    required this.quote,
    required this.state,
    super.key,
  });

  final QuoteRequest quote;
  final ProviderCaseState state;

  @override
  Widget build(BuildContext context) {
    final offer =
        quote.acceptedOffer ?? quote.pendingOffer ?? quote.expiredOffer;
    final service = quote.service?.title.trim() ?? '';
    final String text;
    if (offer == null) {
      text = service.isEmpty ? 'طلبه عرض سعر' : 'طلبه: $service';
    } else {
      final title = offer.title?.trim().isNotEmpty == true
          ? offer.title!.trim()
          : service;
      // Days left only while the offer is open (no expiry on a request, F8).
      final open = identical(offer, quote.pendingOffer);
      text = [
        'عرضك: $title',
        ?providerGroupedAmount(offer.amount),
        if (open && offer.validUntil != null)
          providerDaysLeftLabel(offer.validUntil!.toLocal()),
      ].where((part) => part.trim().isNotEmpty).join(' · ');
    }
    return AarastPressable(
      key: const Key('provider-chat-strip'),
      semanticLabel: '$text، افتح الطلب',
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(AppRouter.providerRequest(quote.id)),
      child: JourneyBox(
        color: AarastV3Color.primarySoft,
        radius: 16,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              LucideIcons.fileText,
              size: 18,
              color: AarastV3Color.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: JourneyType.of(
                  JourneyType.detail,
                  weight: JourneyType.bold,
                  color: AarastV3Color.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ProviderCaseTag(state: state),
          ],
        ),
      ),
    );
  }
}
