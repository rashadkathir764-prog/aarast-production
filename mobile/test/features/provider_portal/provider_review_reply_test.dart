import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_review_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'provider_profile_test.dart' show ProfileApi;

// B-09 (p27): one review of his and his one reply.

class _ReplyApi extends ProfileApi {
  _ReplyApi({super.reviews});

  final sent = <String>[];

  @override
  Future<ProviderReview> replyToReview({
    required String reviewId,
    required String body,
  }) async {
    sent.add('$reviewId:$body');
    final review = reviews.firstWhere((item) => item.id == reviewId);
    return ProviderReview(
      id: review.id,
      rating: review.rating,
      userName: review.userName,
      comment: review.comment,
      createdAt: review.createdAt,
      reply: ProviderReviewReply(body: body.trim(), repliedAt: DateTime(2026, 10, 25)),
    );
  }
}

final _review = ProviderReview(
  id: 'review-1',
  rating: 4,
  userName: 'محمد',
  comment: 'الصور رهيبة، بس الفيلم تأخر أسبوعين عن الموعد.',
  createdAt: DateTime(2026, 10, 10),
);

Future<_ReplyApi> _pump(WidgetTester tester, List<ProviderReview> reviews) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1000);
  addTearDown(tester.view.reset);
  final api = _ReplyApi(reviews: reviews);
  final dashboard = ProviderDashboardProvider(api);
  await dashboard.loadDashboard();
  await tester.pumpWidget(
    ChangeNotifierProvider<ProviderDashboardProvider>.value(
      value: dashboard,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: ProviderReviewScreen(reviewId: 'review-1')),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('p27: the review, «ردك (مرة وحدة، يشوفه الكل)» and «انشر الرد»', (
    tester,
  ) async {
    final api = await _pump(tester, [_review]);
    expect(find.text('تقييم جديد'), findsOne);
    expect(find.text('محمد'), findsOne);
    expect(find.text('«الصور رهيبة، بس الفيلم تأخر أسبوعين عن الموعد.»'), findsOne);
    expect(find.text('ردك (مرة وحدة، يشوفه الكل)'), findsOne);
    // Reports wait for B-28: no «بلّغ عنه».
    expect(find.textContaining('بلّغ'), findsNothing);

    // Nothing to publish before he writes.
    final publish = find.byKey(const Key('provider-review-reply-publish'));
    await tester.tap(publish);
    await tester.pump();
    expect(api.sent, isEmpty);

    await tester.enterText(
      find.byKey(const Key('provider-review-reply-field')).last,
      'شكرًا يا محمد، ونعتذر عن التأخير.',
    );
    await tester.pump();
    await tester.tap(publish);
    await tester.pumpAndSettle();
    expect(api.sent, ['review-1:شكرًا يا محمد، ونعتذر عن التأخير.']);
    // Once: the box is gone and his words read as customers read them.
    expect(find.byKey(const Key('provider-review-reply-field')), findsNothing);
    expect(find.text('ردك · يشوفه الكل تحت التقييم'), findsOne);
    expect(find.text('شكرًا يا محمد، ونعتذر عن التأخير.'), findsOne);
  });

  testWidgets('a reply the team hid says so and offers no second reply', (
    tester,
  ) async {
    await _pump(tester, [
      ProviderReview(
        id: 'review-1',
        rating: 2,
        userName: 'فهد',
        reply: const ProviderReviewReply(body: 'العريس لغى قبل يوم', status: 'HIDDEN'),
      ),
    ]);
    expect(find.text('التقييم'), findsOne);
    expect(find.text('ردك · فريق اعّرست أخفاه، فما يشوفه العرسان'), findsOne);
    expect(find.byKey(const Key('provider-review-reply-field')), findsNothing);
  });
}
