class ChatUser {
  const ChatUser({required this.id, required this.name, this.avatarUrl});

  factory ChatUser.fromJson(Map<String, dynamic> json) => ChatUser(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    avatarUrl: json['avatarUrl']?.toString(),
  );

  final String id;
  final String name;
  final String? avatarUrl;
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
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.quoteRequestId,
    required this.counterpart,
    required this.unreadCount,
    required this.muted,
    required this.blocked,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageAt,
    this.serviceTitle,
    this.providerName,
    this.blockedByMe = false,
    this.blockedByCounterpart = false,
    this.counterpartLastReadAt,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final quote = _jsonMap(json['quoteRequest']);
    final service = _jsonMap(quote?['service']);
    final provider = _jsonMap(quote?['provider']);
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      quoteRequestId: json['quoteRequestId']?.toString() ?? '',
      counterpart:
          _map(json['counterpart'], ChatUser.fromJson) ??
          const ChatUser(id: '', name: 'مستخدم أعرست'),
      unreadCount: _int(json['unreadCount']),
      muted: json['muted'] == true,
      blocked: json['blocked'] == true,
      blockedByMe: json['blockedByMe'] == true,
      blockedByCounterpart: json['blockedByCounterpart'] == true,
      counterpartLastReadAt: _date(json['counterpartLastReadAt']),
      lastMessage: _map(json['lastMessage'], ChatMessage.fromJson),
      lastMessageAt: _date(json['lastMessageAt']),
      serviceTitle: service?['title']?.toString(),
      providerName: provider?['businessName']?.toString(),
      createdAt:
          _date(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _date(json['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String quoteRequestId;
  final ChatUser counterpart;
  final int unreadCount;
  final bool muted;
  final bool blocked;
  final bool blockedByMe;
  final bool blockedByCounterpart;
  final DateTime? counterpartLastReadAt;
  final ChatMessage? lastMessage;
  final DateTime? lastMessageAt;
  final String? serviceTitle;
  final String? providerName;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatConversation copyWith({
    int? unreadCount,
    bool? muted,
    bool? blocked,
    bool? blockedByMe,
    bool? blockedByCounterpart,
    DateTime? counterpartLastReadAt,
    ChatMessage? lastMessage,
    DateTime? lastMessageAt,
  }) {
    return ChatConversation(
      id: id,
      quoteRequestId: quoteRequestId,
      counterpart: counterpart,
      unreadCount: unreadCount ?? this.unreadCount,
      muted: muted ?? this.muted,
      blocked: blocked ?? this.blocked,
      blockedByMe: blockedByMe ?? this.blockedByMe,
      blockedByCounterpart: blockedByCounterpart ?? this.blockedByCounterpart,
      counterpartLastReadAt:
          counterpartLastReadAt ?? this.counterpartLastReadAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      serviceTitle: serviceTitle,
      providerName: providerName,
    );
  }
}

class ChatMessagePage {
  const ChatMessagePage({required this.items, this.nextCursor});

  factory ChatMessagePage.fromJson(Map<String, dynamic> json) =>
      ChatMessagePage(
        items: _list(json['items'], ChatMessage.fromJson),
        nextCursor: json['nextCursor']?.toString(),
      );

  final List<ChatMessage> items;
  final String? nextCursor;
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
