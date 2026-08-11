import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_header_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  Widget app(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  testWidgets('header avatar uses the first name character without an image', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(AarastHeaderAvatarAction(userName: 'رشاد محمد', onTap: () {})),
    );

    expect(
      find.byKey(const ValueKey('aarast-header-avatar-fallback')),
      findsOne,
    );
    expect(find.text('ر'), findsOneWidget);
    expect(find.byIcon(LucideIcons.user), findsNothing);
    expect(
      tester.getSize(find.byType(AarastHeaderAvatarAction)),
      const Size(48, 48),
    );
  });

  testWidgets('header avatar renders the authenticated image URL', (
    tester,
  ) async {
    const avatarUrl = 'https://media.example.com/avatar.jpg';
    await tester.pumpWidget(
      app(
        AarastHeaderAvatarAction(
          userName: 'رشاد',
          avatarUrl: avatarUrl,
          onTap: () {},
        ),
      ),
    );

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('aarast-header-avatar-image')),
    );
    expect(image.image, isA<NetworkImage>());
    expect((image.image as NetworkImage).url, avatarUrl);
  });

  testWidgets('notification action is borderless and keeps a 48px target', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        AarastHeaderIconAction(
          icon: LucideIcons.bell,
          label: 'التنبيهات',
          badgeCount: 4,
          onTap: () {},
        ),
      ),
    );

    expect(find.byIcon(LucideIcons.bell), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(
      tester.getSize(find.byType(AarastHeaderIconAction)),
      const Size(48, 48),
    );

    final decoratedContainers = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(AarastHeaderIconAction),
            matching: find.byType(Container),
          ),
        )
        .where((container) => container.decoration is BoxDecoration)
        .map((container) => container.decoration! as BoxDecoration)
        .toList();
    expect(
      decoratedContainers.where(
        (decoration) => decoration.shape == BoxShape.circle,
      ),
      isEmpty,
    );
  });
}
