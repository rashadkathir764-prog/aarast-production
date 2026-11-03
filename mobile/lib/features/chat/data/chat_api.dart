import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_contract.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../models/chat_models.dart';

/// Conversations with providers and the plan's partners.
///
/// D85: the first page of conversations, each conversation and the first
/// page of its timeline are the phone's copy when the server is out of
/// reach, so an old chat still reads. A message needs the other side to
/// receive it now, so sending says so instead of pretending; reading and
/// muting are kept on the phone and sent when the server answers.
class ChatApi {
  ChatApi(ApiClient apiClient, {OfflineSyncService? offline})
    : _reads = OfflineReads(apiClient, offline),
      _writes = OfflineWrites(apiClient, offline);

  final OfflineReads _reads;
  final OfflineWrites _writes;

  static const _sendReason = 'الرسالة تحتاج الخادم عشان توصل للطرف الثاني.';

  Future<ChatConversationPage> listConversations({String? cursor}) async {
    if (cursor == null) {
      return ChatConversationPage.fromJson(
        await _reads.blob('/api/v1/conversations', metaKey: 'chat:list'),
      );
    }
    final suffix = '?cursor=${Uri.encodeQueryComponent(cursor)}';
    return ChatConversationPage.fromJson(
      await _writes.serverOnly(
        reason: 'الصفحات التالية عند الخادم.',
        method: 'GET',
        path: '/api/v1/conversations$suffix',
      ),
    );
  }

  /// The phone's copy of the first page alone.
  Future<ChatConversationPage?> cachedConversations() async {
    final json = await _reads.cachedBlob('chat:list');
    return json == null ? null : ChatConversationPage.fromJson(json);
  }

  Future<ChatConversation> conversationForQuote(String quoteRequestId) async {
    return ChatConversation.fromJson(
      await _reads.blob(
        '/api/v1/quote-requests/$quoteRequestId/conversation',
        metaKey: 'chat:quote:$quoteRequestId',
      ),
    );
  }

  Future<ChatConversation> getConversation(String conversationId) async {
    return ChatConversation.fromJson(
      await _reads.blob(
        '/api/v1/conversations/$conversationId',
        metaKey: 'chat:conversation:$conversationId',
      ),
    );
  }

  Future<ChatTimelinePage> timeline(
    String conversationId, {
    String? cursor,
  }) async {
    if (cursor == null) {
      return ChatTimelinePage.fromJson(
        await _reads.blob(
          '/api/v1/conversations/$conversationId/timeline',
          metaKey: 'chat:timeline:$conversationId',
        ),
      );
    }
    final suffix = '?cursor=${Uri.encodeQueryComponent(cursor)}';
    return ChatTimelinePage.fromJson(
      await _writes.serverOnly(
        reason: 'الرسائل الأقدم عند الخادم.',
        method: 'GET',
        path: '/api/v1/conversations/$conversationId/timeline$suffix',
      ),
    );
  }

  /// The phone's copy of the first page of the timeline alone.
  Future<ChatTimelinePage?> cachedTimeline(String conversationId) async {
    final json = await _reads.cachedBlob('chat:timeline:$conversationId');
    return json == null ? null : ChatTimelinePage.fromJson(json);
  }

  Future<ChatQuoteRequestPage> quoteRequests(String conversationId) async {
    return ChatQuoteRequestPage.fromJson(
      await _reads.blob(
        '/api/v1/conversations/$conversationId/quote-requests',
        metaKey: 'chat:quotes:$conversationId',
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
    final json = await _writes.serverOnly(
      reason: _sendReason,
      method: 'POST',
      path: '/api/v1/conversations/$conversationId/messages',
      body: {
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
      },
      clientRequestId: clientRequestId,
    );
    return ChatMessage.fromJson(json);
  }

  Future<ChatAttachmentAccess> refreshAttachment(
    String conversationId,
    String attachmentId,
  ) async {
    final json = await _writes.serverOnly(
      reason: 'رابط الملف يصدره الخادم لمدة قصيرة.',
      method: 'GET',
      path:
          '/api/v1/conversations/$conversationId/attachments/$attachmentId/download',
    );
    return ChatAttachmentAccess.fromJson(json);
  }

  Future<void> markRead(String conversationId) async {
    await _writes.queued(
      entityType: 'conversation',
      operation: 'read',
      method: 'PATCH',
      endpoint: '/api/v1/conversations/$conversationId/read',
      payload: const {},
      metaKey: 'chat:read:$conversationId',
      localJson: {
        'id': conversationId,
        'readAt': DateTime.now().toIso8601String(),
      },
      localEntityId: conversationId,
      replacePendingForEntity: true,
    );
  }

  Future<void> setMuted(String conversationId, bool enabled) async {
    await _writes.queued(
      entityType: 'conversation',
      operation: 'mute',
      method: 'PATCH',
      endpoint: '/api/v1/conversations/$conversationId/mute',
      payload: {'enabled': enabled},
      metaKey: 'chat:mute:$conversationId',
      localJson: {'id': conversationId, 'muted': enabled},
      localEntityId: 'mute:$conversationId',
      replacePendingForEntity: true,
    );
  }

  Future<void> setBlocked(String conversationId, bool enabled) async {
    await _writes.serverOnly(
      reason: 'الحظر يُسجَّل عند الخادم.',
      method: 'PATCH',
      path: '/api/v1/conversations/$conversationId/block',
      body: {'enabled': enabled},
    );
  }

  Future<void> report(String conversationId, String reason) async {
    await _writes.serverOnly(
      reason: 'البلاغ يوصل للإدارة من الخادم.',
      method: 'POST',
      path: '/api/v1/conversations/$conversationId/report',
      body: {'reason': reason},
    );
  }
}
