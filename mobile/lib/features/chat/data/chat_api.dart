import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../models/chat_models.dart';

class ChatApi {
  const ChatApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ChatConversation>> listConversations() async {
    final list = await _apiClient.getJsonList('/conversations');
    return list
        .whereType<Map>()
        .map(
          (item) => ChatConversation.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<ChatConversation> ensureForQuote(String quoteRequestId) async {
    final json = await _apiClient.postJson(
      '/conversations/quote-requests/$quoteRequestId',
      const {},
    );
    return ChatConversation.fromJson(json);
  }

  Future<ChatMessagePage> messages(
    String conversationId, {
    String? cursor,
  }) async {
    final suffix = cursor == null
        ? ''
        : '?cursor=${Uri.encodeQueryComponent(cursor)}';
    return ChatMessagePage.fromJson(
      await _apiClient.getJson(
        '/conversations/$conversationId/messages$suffix',
      ),
    );
  }

  Future<ChatMessage> send(
    String conversationId, {
    required String body,
    List<MediaUploadTicket> attachments = const [],
  }) async {
    final json = await _apiClient.postJson(
      '/conversations/$conversationId/messages',
      {
        'body': body,
        if (attachments.isNotEmpty)
          'attachments': attachments
              .map(
                (item) => {
                  'url': item.publicUrl,
                  'contentType': item.contentType,
                  'byteSize': item.byteSize,
                },
              )
              .toList(),
      },
    );
    return ChatMessage.fromJson(json);
  }

  Future<void> markRead(String conversationId) async {
    await _apiClient.patchJson('/conversations/$conversationId/read', const {});
  }

  Future<void> setMuted(String conversationId, bool enabled) async {
    await _apiClient.patchJson('/conversations/$conversationId/mute', {
      'enabled': enabled,
    });
  }

  Future<void> setBlocked(String conversationId, bool enabled) async {
    await _apiClient.patchJson('/conversations/$conversationId/block', {
      'enabled': enabled,
    });
  }

  Future<void> report(String conversationId, String reason) async {
    await _apiClient.postJson('/conversations/$conversationId/report', {
      'reason': reason,
    });
  }
}
