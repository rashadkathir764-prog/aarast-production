import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/my_wedding_plans_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('MyWeddingPlansScreen is RTL and overflow-free at 320px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.reset);

    final auth = await _authController();
    final apiClient = ApiClient(tokenProvider: () async => null);
    final plans = _EmptyWeddingPlansProvider(apiClient);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<WeddingPlansProvider>.value(value: plans),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: MyWeddingPlansScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MyWeddingPlansScreen), findsOneWidget);
    expect(find.bySemanticsLabel('فتح الحساب'), findsOneWidget);
    expect(find.bySemanticsLabel('عرض خططي'), findsOneWidget);
    expect(find.bySemanticsLabel('عرض الخطط المشتركة'), findsOneWidget);
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason: exception is FlutterError
          ? '${exception.toStringDeep()}\n${_overflowingFlexes(tester)}'
          : exception?.toString(),
    );
  });
}

String _overflowingFlexes(WidgetTester tester) {
  final details = <String>[];
  for (final element in tester.allElements) {
    final render = element.renderObject;
    if (render is! RenderFlex || !render.hasSize) continue;
    var child = render.firstChild;
    var overflow = false;
    final childBounds = <String>[];
    while (child != null) {
      final data = child.parentData! as FlexParentData;
      final bounds = data.offset & child.size;
      overflow =
          overflow ||
          bounds.left < -0.5 ||
          bounds.top < -0.5 ||
          bounds.right > render.size.width + 0.5 ||
          bounds.bottom > render.size.height + 0.5;
      childBounds.add('${child.runtimeType}:${child.size}@${data.offset}');
      child = render.childAfter(child);
    }
    if (!overflow) continue;

    final ancestors = <String>[];
    Element? cursor = element;
    for (var depth = 0; cursor != null && depth < 6; depth += 1) {
      final Element current = cursor!;
      ancestors.add(current.widget.runtimeType.toString());
      current.visitAncestorElements((ancestor) {
        cursor = ancestor;
        return false;
      });
    }
    details.add(
      'RenderFlex ${render.direction} size=${render.size} '
      'widgets=${ancestors.join(' <- ')} children=${childBounds.join(', ')}',
    );
  }
  return details.join('\n');
}

Future<AuthController> _authController() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final storage = AuthStorage(preferences);
  final client = ApiClient(tokenProvider: storage.readAccessToken);
  return AuthController(AuthRepository(client, storage));
}

class _EmptyWeddingPlansProvider extends WeddingPlansProvider {
  _EmptyWeddingPlansProvider(ApiClient apiClient)
    : super(WeddingPlansApi(apiClient));

  @override
  List<WeddingPlan> get plans => const [];

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> loadMyWeddingPlans() async {}
}
