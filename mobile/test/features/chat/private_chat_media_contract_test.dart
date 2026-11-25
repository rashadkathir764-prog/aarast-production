import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:aarast_mobile/core/media/media_upload_api.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';

void main() {
  test('chat attachment parses a short-lived private access grant', () {
    final attachment = ChatAttachment.fromJson({
      'id': 'attachment-1',
      'url': 'https://storage.example.test/private?X-Amz-Expires=120',
      'contentType': 'image/webp',
      'byteSize': 2048,
      'expiresAt': '2026-07-10T12:02:00.000Z',
    });

    expect(attachment.id, 'attachment-1');
    expect(attachment.url, contains('X-Amz-Expires=120'));
    expect(attachment.expiresAt, DateTime.utc(2026, 7, 10, 12, 2));
  });

  // RA-TS-24: the request itself, caught on its way out, in place of a read
  // of chat_api.dart's text.
  test('chat sends an opaque attachmentRef and never the public URL', () async {
    final client = _RecordingClient();
    await ChatApi(client).send(
      'conversation-1',
      body: 'صورة القاعة',
      attachments: const [
        MediaUploadTicket(
          key: 'chat/2026/07/hall.webp',
          attachmentRef: 'ref-opaque-1',
          uploadUrl: 'https://storage.example.test/upload?sig=abc',
          publicUrl: 'https://cdn.example.test/public/hall.webp',
          contentType: 'image/webp',
          byteSize: 2048,
        ),
      ],
    );

    expect(client.method, 'POST');
    expect(client.path, '/api/v1/conversations/conversation-1/messages');
    expect(client.body, {
      'body': 'صورة القاعة',
      'attachments': [
        {
          'attachmentRef': 'ref-opaque-1',
          'contentType': 'image/webp',
          'byteSize': 2048,
        },
      ],
    });
    final wire = jsonEncode(client.body);
    expect(wire, isNot(contains('cdn.example.test')));
    expect(wire, isNot(contains('hall.webp')));
    expect(wire, isNot(contains('uploadUrl')));
  });

  test('a message with no file carries no attachments key', () async {
    final client = _RecordingClient();
    await ChatApi(client).send('conversation-1', body: 'السلام عليكم');

    expect(client.body, {'body': 'السلام عليكم'});
  });

  test(
    'an attachment is opened through its conversation\'s download route',
    () async {
      final client = _RecordingClient()
        ..answer = {
          'url': 'https://storage.example.test/private?X-Amz-Expires=120',
          'expiresAt': '2026-07-10T12:02:00.000Z',
        };
      final access = await ChatApi(
        client,
      ).refreshAttachment('conversation-1', 'attachment-9');

      expect(client.method, 'GET');
      expect(
        client.path,
        '/api/v1/conversations/conversation-1/attachments/attachment-9/download',
      );
      expect(access.url, contains('X-Amz-Expires=120'));
      expect(access.expiresAt, DateTime.utc(2026, 7, 10, 12, 2));
    },
  );
}

class _RecordingClient extends ApiClient {
  _RecordingClient() : super(tokenProvider: () async => null);

  String? method;
  String? path;
  Map<String, dynamic>? body;
  Map<String, dynamic> answer = const {};

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    method = 'GET';
    this.path = path;
    return answer;
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    method = 'POST';
    this.path = path;
    body = data;
    return {'id': 'message-1', 'conversationId': 'conversation-1'};
  }
}
