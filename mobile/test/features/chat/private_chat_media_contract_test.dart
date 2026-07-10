import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  test('chat sends an opaque attachmentRef and never the public URL', () {
    final source = File(
      'lib/features/chat/data/chat_api.dart',
    ).readAsStringSync();

    expect(source, contains("'attachmentRef': item.attachmentRef"));
    expect(source, isNot(contains("'url': item.publicUrl")));
    expect(source, contains('/attachments/\$attachmentId/download'));
  });
}
