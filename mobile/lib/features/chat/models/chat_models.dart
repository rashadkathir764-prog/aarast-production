import '../../../core/utils/offer_changes.dart';

enum ChatConversationScope { plan, account }

class ChatUser {
  const ChatUser({required this.id, required this.name, this.avatarUrl});

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
    id: json['id']?.toString() ?? '',
    // B-14: the provider's side of a plan conversation names the customer
    // by first name only (`{ firstName, weddingLabel, eventDate }`).
    name: (json['name'] ?? json['firstName'])?.toString() ?? '',
    avatarUrl: json['avatarUrl']?.toString(),
  );

  final String id;
  final String name;
  final String? avatarUrl;
}

class ChatWeddingPlan {
  const ChatWeddingPlan({required this.id, required this.title});

  factory ChatWeddingPlan.fromJson(Map<String, dynamic> json) =>
      ChatWeddingPlan(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
      );

  final String id;
  final String title;
}

class ChatProviderSummary {
  const ChatProviderSummary({
    required this.id,
    required this.businessName,
    this.logoUrl,
  });

  factory ChatProviderSummary.fromJson(Map<String, dynamic> json) =>
      ChatProviderSummary(
        id: json['id']?.toString() ?? '',
        businessName: json['businessName']?.toString() ?? '',
        logoUrl: json['logoUrl']?.toString(),
      );

  final String id;
  final String businessName;
  final String? logoUrl;
}

class ChatConversationPermissions {
  const ChatConversationPermissions({
    required this.canManageProviders,
    required this.canViewMoney,
    required this.canManageMoney,
    required this.canViewContact,
  });

  factory ChatConversationPermissions.fromJson(Map<String, dynamic> json) =>
      ChatConversationPermissions(
        canManageProviders: json['canManageProviders'] == true,
        canViewMoney: json['canViewMoney'] == true,
        canManageMoney: json['canManageMoney'] == true,
        canViewContact: json['canViewContact'] == true,
      );

  static const none = ChatConversationPermissions(
    canManageProviders: false,
    canViewMoney: false,
    canManageMoney: false,
    canViewContact: false,
  );

  final bool canManageProviders;
  final bool canViewMoney;
  final bool canManageMoney;
  final bool canViewContact;
}

class ChatQuoteService {
  const ChatQuoteService({required this.id, required this.title});

  factory ChatQuoteService.fromJson(Map<String, dynamic> json) =>
      ChatQuoteService(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
      );

  final String id;
  final String title;
}

/// An offer on a request, as the conversation shows it (f06). [amount] is
/// null when the viewer may not see money.
class ChatQuoteOffer {
  const ChatQuoteOffer({
    required this.id,
    required this.status,
    this.title,
    this.message,
    this.amount,
    this.currency,
    this.validUntil,
    this.versionNo = 1,
    this.changes = const [],
  });

  factory ChatQuoteOffer.fromJson(Map<String, dynamic> json) {
    final changes = json['changes'];
    return ChatQuoteOffer(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      title: json['title']?.toString(),
      message: json['message']?.toString(),
      amount: json['amount']?.toString(),
      currency: json['currency']?.toString(),
      validUntil: _date(json['validUntil']),
      versionNo: json['versionNo'] is num
          ? (json['versionNo'] as num).toInt()
          : 1,
      changes: changes is List
          ? [
              for (final item in changes.whereType<Map>())
                QuoteOfferChange.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
    );
  }

  final String id;
  final String status;
  final String? title;
  final String? message;
  final String? amount;
  final String? currency;
  final DateTime? validUntil;

  /// B-06: the version read, and «ايش تغيّر» against the one before.
  final int versionNo;
  final List<QuoteOfferChange> changes;
}

class ChatQuoteRequestSummary {
  const ChatQuoteRequestSummary({
    required this.id,
    required this.status,
    required this.createdAt,
    this.service,
    this.message,
    this.contactName,
    this.offers = const [],
  });

  factory ChatQuoteRequestSummary.fromJson(Map<String, dynamic> json) =>
      ChatQuoteRequestSummary(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        createdAt:
            _date(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        service: _map(json['service'], ChatQuoteService.fromJson),
        message: json['message']?.toString(),
        contactName: json['contactName']?.toString(),
        offers: _list(json['offers'], ChatQuoteOffer.fromJson),
      );

  final String id;
  final String status;
  final DateTime createdAt;
  final ChatQuoteService? service;

  /// What the customer wrote with the request.
  final String? message;

  /// The name the customer left on the request; the server sends it only to
  /// those allowed to see contact details.
  final String? contactName;
  final List<ChatQuoteOffer> offers;
}

class ChatAttachment {
  const ChatAttachment({
    required this.id,
    required this.url,
    required this.contentType,
    required this.byteSize,
    this.expiresAt,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
    id: json['id']?.toString() ?? '',
    url: json['url']?.toString() ?? '',
    contentType: json['contentType']?.toString() ?? '',
    byteSize: _int(json['byteSize']),
    expiresAt: _date(json['expiresAt']),
  );

  final String id;
  final String url;
  final String contentType;
  final int byteSize;
  final DateTime? expiresAt;
}

class ChatAttachmentAccess {
  const ChatAttachmentAccess({required this.url, required this.expiresAt});

  factory ChatAttachmentAccess.fromJson(Map<String, dynamic> json) =>
      ChatAttachmentAccess(
        url: json['url']?.toString() ?? '',
        expiresAt: _date(json['expiresAt']),
      );

  final String url;
  final DateTime? expiresAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
    this.sender,
    this.attachments = const [],
    this.pending = false,
    this.queued = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id']?.toString() ?? '',
    conversationId: json['conversationId']?.toString() ?? '',
    senderUserId: json['senderUserId']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    sender: _map(json['sender'], ChatUser.fromJson),
    attachments: _list(json['attachments'], ChatAttachment.fromJson),
  );

  final String id;
  final String conversationId;
  final String senderUserId;
  final String body;
  final DateTime createdAt;
  final ChatUser? sender;
  final List<ChatAttachment> attachments;
  final bool pending;

  /// G38: written with no network; it goes when the network is back.
  final bool queued;
}

class ChatConversationEvent {
  const ChatConversationEvent({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.occurredAt,
    this.quoteRequestId,
    this.quoteOfferId,
    this.data,
  });

  factory ChatConversationEvent.fromJson(Map<String, dynamic> json) =>
      ChatConversationEvent(
        id: json['id']?.toString() ?? '',
        conversationId: json['conversationId']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        occurredAt:
            _date(json['occurredAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        quoteRequestId: json['quoteRequestId']?.toString(),
        quoteOfferId: json['quoteOfferId']?.toString(),
        data: _jsonMap(json['data']),
      );

  final String id;
  final String conversationId;
  final String type;
  final DateTime occurredAt;
  final String? quoteRequestId;
  final String? quoteOfferId;
  final Map<String, dynamic>? data;
}

enum ChatTimelineItemKind { message, event }

class ChatTimelineItem {
  const ChatTimelineItem._({
    required this.kind,
    required this.occurredAt,
    this.message,
    this.event,
  });

  factory ChatTimelineItem.fromJson(Map<String, dynamic> json) {
    final kind = json['kind']?.toString();
    if (kind == 'EVENT') {
      return ChatTimelineItem._(
        kind: ChatTimelineItemKind.event,
        occurredAt:
            _date(json['occurredAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        event: _map(json['event'], ChatConversationEvent.fromJson),
      );
    }
    return ChatTimelineItem._(
      kind: ChatTimelineItemKind.message,
      occurredAt:
          _date(json['occurredAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      message: _map(json['message'], ChatMessage.fromJson),
    );
  }

  factory ChatTimelineItem.pending(ChatMessage message) => ChatTimelineItem._(
    kind: ChatTimelineItemKind.message,
    occurredAt: message.createdAt,
    message: message,
  );

  final ChatTimelineItemKind kind;
  final DateTime occurredAt;
  final ChatMessage? message;
  final ChatConversationEvent? event;

  String get identity => switch (kind) {
    ChatTimelineItemKind.message => 'M:${message?.id ?? ''}',
    ChatTimelineItemKind.event => 'E:${event?.id ?? ''}',
  };
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.scope,
    required this.provider,
    required this.quoteRequestCount,
    required this.unreadMessageCount,
    required this.muted,
    required this.blocked,
    required this.providerJoined,
    required this.canSend,
    required this.permissions,
    required this.lastActivityAt,
    required this.createdAt,
    required this.updatedAt,
    this.weddingPlan,
    this.latestQuoteRequest,
    this.counterpart,
    this.lastMessage,
    this.blockedByMe = false,
    this.blockedByCounterpart = false,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) =>
      ChatConversation(
        id: json['id']?.toString() ?? '',
        scope: json['scope']?.toString() == 'ACCOUNT'
            ? ChatConversationScope.account
            : ChatConversationScope.plan,
        weddingPlan: _map(json['weddingPlan'], ChatWeddingPlan.fromJson),
        provider:
            _map(json['provider'], ChatProviderSummary.fromJson) ??
            const ChatProviderSummary(id: '', businessName: 'مزود'),
        counterpart: _map(json['counterpart'], ChatUser.fromJson),
        quoteRequestCount: _int(json['quoteRequestCount']),
        latestQuoteRequest: _map(
          json['latestQuoteRequest'],
          ChatQuoteRequestSummary.fromJson,
        ),
        lastMessage: _map(json['lastMessage'], ChatMessage.fromJson),
        lastActivityAt:
            _date(json['lastActivityAt']) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        unreadMessageCount: _int(json['unreadMessageCount']),
        muted: json['muted'] == true,
        blocked: json['blocked'] == true,
        blockedByMe: json['blockedByMe'] == true,
        blockedByCounterpart: json['blockedByCounterpart'] == true,
        providerJoined: json['providerJoined'] == true,
        canSend: json['canSend'] == true,
        permissions:
            _map(json['permissions'], ChatConversationPermissions.fromJson) ??
            ChatConversationPermissions.none,
        createdAt:
            _date(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt:
            _date(json['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  final String id;
  final ChatConversationScope scope;
  final ChatWeddingPlan? weddingPlan;
  final ChatProviderSummary provider;
  final ChatUser? counterpart;
  final int quoteRequestCount;
  final ChatQuoteRequestSummary? latestQuoteRequest;
  final ChatMessage? lastMessage;
  final DateTime lastActivityAt;
  final int unreadMessageCount;
  final bool muted;
  final bool blocked;
  final bool blockedByMe;
  final bool blockedByCounterpart;
  final bool providerJoined;
  final bool canSend;
  final ChatConversationPermissions permissions;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The provider answers this conversation: the server gives the provider's
  /// side no right to manage providers, and a customer without that right
  /// never sees the conversation at all.
  bool get viewerIsProvider => !permissions.canManageProviders;

  /// The other side's name: the provider's business for the customer, the
  /// customer for the provider, named as his request is. The account gives
  /// the provider a first name only (B-14), so it comes second.
  String get counterpartName {
    if (!viewerIsProvider) return provider.businessName;
    final contact = latestQuoteRequest?.contactName?.trim();
    if (contact != null && contact.isNotEmpty) return contact;
    final name = counterpart?.name.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'العميل';
  }

  ChatConversation copyWith({
    int? unreadMessageCount,
    bool? muted,
    bool? blocked,
    bool? blockedByMe,
    bool? blockedByCounterpart,
    bool? providerJoined,
    bool? canSend,
    ChatMessage? lastMessage,
    DateTime? lastActivityAt,
  }) => ChatConversation(
    id: id,
    scope: scope,
    weddingPlan: weddingPlan,
    provider: provider,
    counterpart: counterpart,
    quoteRequestCount: quoteRequestCount,
    latestQuoteRequest: latestQuoteRequest,
    lastMessage: lastMessage ?? this.lastMessage,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    unreadMessageCount: unreadMessageCount ?? this.unreadMessageCount,
    muted: muted ?? this.muted,
    blocked: blocked ?? this.blocked,
    blockedByMe: blockedByMe ?? this.blockedByMe,
    blockedByCounterpart: blockedByCounterpart ?? this.blockedByCounterpart,
    providerJoined: providerJoined ?? this.providerJoined,
    canSend: canSend ?? this.canSend,
    permissions: permissions,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

class ChatTimelinePage {
  const ChatTimelinePage({required this.items, this.nextCursor});

  factory ChatTimelinePage.fromJson(Map<String, dynamic> json) =>
      ChatTimelinePage(
        items: _list(json['items'], ChatTimelineItem.fromJson),
        nextCursor: json['nextCursor']?.toString(),
      );

  final List<ChatTimelineItem> items;
  final String? nextCursor;
}

class ChatQuoteRequestPage {
  const ChatQuoteRequestPage({required this.items});

  factory ChatQuoteRequestPage.fromJson(Map<String, dynamic> json) =>
      ChatQuoteRequestPage(
        items: _list(json['items'], ChatQuoteRequestSummary.fromJson),
      );

  final List<ChatQuoteRequestSummary> items;
}

class ChatConversationPage {
  const ChatConversationPage({required this.items, this.nextCursor});

  factory ChatConversationPage.fromJson(Map<String, dynamic> json) =>
      ChatConversationPage(
        items: _list(json['items'], ChatConversation.fromJson),
        nextCursor: json['nextCursor']?.toString(),
      );

  final List<ChatConversation> items;
  final String? nextCursor;
}

T? _map<T>(Object? value, T Function(Map<String, dynamic>) mapper) {
  final map = _jsonMap(value);
  return map == null ? null : mapper(map);
}

Map<String, dynamic>? _jsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) mapper) {
  if (value is! List) return const [];
  return value
      .map(_jsonMap)
      .whereType<Map<String, dynamic>>()
      .map(mapper)
      .toList(growable: false);
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;
