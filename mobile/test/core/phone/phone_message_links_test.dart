import 'package:aarast_mobile/core/phone/phone_message_links.dart';
import 'package:flutter_test/flutter_test.dart';

// A task given to someone leaves the owner's phone as a WhatsApp chat or a
// text message, the words already written.

void main() {
  const text = 'السلام عليكم\nحجز القاعة';

  test('WhatsApp opens the person\'s chat with the words ready', () {
    final uri = whatsAppMessageUri('777123456', text)!;

    expect(uri.scheme, 'https');
    expect(uri.host, 'wa.me');
    expect(uri.path, '/967777123456');
    expect(uri.queryParameters['text'], text);
    // Spaces travel as %20: a «+» stays a «+» in some apps.
    expect(uri.toString(), isNot(contains('+')));
  });

  test('a text message goes to the same number with the same words', () {
    final uri = smsMessageUri('777123456', text)!;

    expect(uri.scheme, 'sms');
    expect(uri.path, '+967777123456');
    expect(uri.queryParameters['body'], text);
    expect(uri.toString(), startsWith('sms:+967777123456?body='));
    expect(uri.query, isNot(contains('+')));
  });

  test('no number, no address', () {
    expect(whatsAppMessageUri(null, text), isNull);
    expect(whatsAppMessageUri('  ', text), isNull);
    expect(smsMessageUri(null, text), isNull);
    expect(smsMessageUri('', text), isNull);
  });
}
