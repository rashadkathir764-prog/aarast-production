import 'package:aarast_mobile/features/finance/models/quote_finance_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuoteFinanceContext', () {
    test('builds human finance title and note from an accepted quote', () {
      const context = QuoteFinanceContext(
        quoteRequestId: 'quote-1',
        providerId: 'provider-1',
        providerName: 'قاعة الورد',
        quoteOfferId: 'offer-1',
        serviceTitle: 'قاعة زفاف',
        amount: '150000',
        currency: 'YER',
      );

      expect(context.title, 'قاعة زفاف - قاعة الورد');
      expect(context.note, contains('مرتبط بعرض سعر من قاعة الورد.'));
      expect(context.note, contains('رقم الطلب: quote-1.'));
      expect(context.note, contains('رقم العرض: offer-1.'));
    });

    test('falls back to provider name when service title is missing', () {
      const context = QuoteFinanceContext(
        quoteRequestId: 'quote-1',
        providerId: 'provider-1',
        providerName: 'مصور النور',
      );

      expect(context.title, 'عرض مصور النور');
    });
  });
}
