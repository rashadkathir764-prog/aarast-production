import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// G38: a text message written with no network, kept on this phone until it
/// reaches the server. Each keeps the request id it was first sent with, so
/// a message whose answer was lost is never doubled (the server replays the
/// first answer for the same `X-Client-Request-Id`).
class ChatOutboxMessage {
  const ChatOutboxMessage({
    required this.localId,
    required this.conversationId,
    required this.body,
    required this.clientRequestId,
    required this.createdAt,
    this.refusedReason,
  });

  factory ChatOutboxMessage.fromJson(Map<String, dynamic> json) =>
      ChatOutboxMessage(
        localId: json['localId'].toString(),
        conversationId: json['conversationId'].toString(),
        body: json['body'].toString(),
        clientRequestId: json['clientRequestId'].toString(),
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        refusedReason: json['refusedReason']?.toString(),
      );

  final String localId;
  final String conversationId;
  final String body;
  final String clientRequestId;
  final DateTime createdAt;

  /// RA-BE-95: the server refused this message for good (the chat was
  /// closed or blocked, the provider stopped) after it waited on the phone.
  /// It is not sent again; its words go back to the chat's box, with this
  /// reason, the next time the chat opens, as a refused message typed online
  /// stays in the box.
  final String? refusedReason;

  bool get isRefused => refusedReason != null;

  ChatOutboxMessage refused(String reason) => ChatOutboxMessage(
    localId: localId,
    conversationId: conversationId,
    body: body,
    clientRequestId: clientRequestId,
    createdAt: createdAt,
    refusedReason: reason,
  );

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'conversationId': conversationId,
    'body': body,
    'clientRequestId': clientRequestId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'refusedReason': ?refusedReason,
  };
}

/// The waiting messages of one account, in the order written.
class ChatOutbox {
  const ChatOutbox(this._preferences);

  final SharedPreferences _preferences;

  static String _key(String userId) => 'aarast_chat_outbox:$userId';

  List<ChatOutboxMessage> read(String userId) {
    final raw = _preferences.getString(_key(userId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final item in list)
          if (item is Map)
            ChatOutboxMessage.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> write(String userId, List<ChatOutboxMessage> messages) {
    if (messages.isEmpty) return _preferences.remove(_key(userId));
    return _preferences.setString(
      _key(userId),
      jsonEncode([for (final message in messages) message.toJson()]),
    );
  }
}
