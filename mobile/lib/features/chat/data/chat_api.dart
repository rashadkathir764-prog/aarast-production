import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../models/chat_models.dart';

class ChatApi {
  const ChatApi(this._apiClient);

  final ApiClient _apiClient;

  Future<ChatConversationPage> listConversations({String? cursor}) async {
    final suffix = cursor == null
        ? ''
        : '?cursor=${Uri.encodeQueryComponent(cursor)}';
    return ChatConversationPage.fromJson(
      await _apiClient.getJson('/api/v1/conversations$suffix'),
    );
  }

  Future<ChatConversation> conversationForQuote(String quoteRequestId) async {
    final json = await _apiClient.getJson(
      '/api/v1/quote-requests/$quoteRequestId/conversation',
    );
    return ChatConversation.fromJson(json);
  }

  Future<ChatConversation> getConversation(String conversationId) async {
    return ChatConversation.fromJson(
      await _apiClient.getJson('/api/v1/conversations/$conversationId'),
    );
  }

  Future<ChatTimelinePage> timeline(
    String conversationId, {
    String? cursor,
  }) async {
    final suffix = cursor == null
        ? ''
        : '?cursor=${Uri.encodeQueryComponent(cursor)}';
    return ChatTimelinePage.fromJson(
      await _apiClient.getJson(
        '/api/v1/conversations/$conversationId/timeline$suffix',
      ),
    );
  }

  Future<ChatQuoteRequestPage> quoteRequests(String conversationId) async {
    return ChatQuoteRequestPage.fromJson(
      await _apiClient.getJson(
        '/api/v1/conversations/$conversationId/quote-requests',
      ),
    );
  }

  /// With [clientRequestId] (G38) a resend of the same message is answered
  /// with the first answer, never a second message.
  Future<ChatMessage> send(
    String conversationId, {
    required String body,
    List<MediaUploadTicket> attachments = const [],
    String? clientRequestId,
  }) async {
    final path = '/api/v1/conversations/$conversationId/messages';
    final payload = {
      'body': body,
      if (attachments.isNotEmpty)
        'attachments': attachments
            .map(
              (item) => {
                'attachmentRef': item.attachmentRef,
                'contentType': item.contentType,
                'byteSize': item.byteSize,
              },
            )
            .toList(),
    };
    final json = clientRequestId == null
        ? await _apiClient.postJson(path, payload)
        : await _apiClient.mutateJson(
            path,
            payload,
            method: 'POST',
            clientRequestId: clientRequestId,
          );
    return ChatMessage.fromJson(json);
  }

  Future<ChatAttachmentAccess> refreshAttachment(
    String conversationId,
    String attachmentId,
  ) async {
    final json = await _apiClient.getJson(
      '/api/v1/conversations/$conversationId/attachments/$attachmentId/download',
    );
    return ChatAttachmentAccess.fromJson(json);
  }

  Future<void> markRead(String conversationId) async {
    await _apiClient.patchJson(
      '/api/v1/conversations/$conversationId/read',
      const {},
    );
  }

  Future<void> setMuted(String conversationId, bool enabled) async {
    await _apiClient.patchJson('/api/v1/conversations/$conversationId/mute', {
      'enabled': enabled,
    });
  }

  Future<void> setBlocked(String conversationId, bool enabled) async {
    await _apiClient.patchJson('/api/v1/conversations/$conversationId/block', {
      'enabled': enabled,
    });
  }

  Future<void> report(String conversationId, String reason) async {
    await _apiClient.postJson('/api/v1/conversations/$conversationId/report', {
      'reason': reason,
    });
  }
}
