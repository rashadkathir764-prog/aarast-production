import 'package:aarast_mobile/core/contacts/contact_picker_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// D112 (Q-10), my choice where the owner left it to me: reading the address
// book stays (guests are picked from it), so the app says what it reads and
// what it keeps, on its own page and before Android's own question, and
// goes on only on a yes. Play refuses an app that asks for contacts without
// that; the app went straight to the system prompt.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_contacts');
  late String status;
  late List<String> calls;

  setUp(() {
    status = 'notDetermined';
    calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'permissions.check' ? status : null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<Future<bool>> ask(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Builder(
            builder: (inner) {
              context = inner;
              return const Scaffold(body: Text('الضيوف'));
            },
          ),
        ),
      ),
    );
    final answer = ContactPickerService.confirmAccess(context);
    await tester.pumpAndSettle();
    return answer;
  }

  // RA-MO-216 (batch 6): the first number of a contact was always taken.
  test('a contact is invited by its Yemeni mobile, wherever it is listed', () {
    expect(
      ContactPickerService.preferredContactPhone([
        '01 234 567',
        '+966501234567',
        '777 123 456',
      ]),
      '777 123 456',
    );
    // None is a Yemeni mobile: the first stands, and is told as it is.
    expect(
      ContactPickerService.preferredContactPhone(['01 234 567', '02 333 444']),
      '01 234 567',
    );
  });

  testWidgets('before the first read the app says what it reads and keeps', (
    tester,
  ) async {
    final answer = await ask(tester);

    expect(find.byKey(const Key('contacts-disclosure')), findsOneWidget);
    expect(find.textContaining('الأسماء والأرقام'), findsOneWidget);
    expect(find.textContaining('ما يطلع من جوالك'), findsOneWidget);
    // Android is not asked before the person answers.
    expect(calls, ['permissions.check']);

    await tester.tap(find.byKey(const Key('contacts-disclosure-agree')));
    await tester.pumpAndSettle();
    expect(await answer, isTrue);
    expect(calls, ['permissions.check']);
  });

  testWidgets('«مو الآن» reads nothing', (tester) async {
    final answer = await ask(tester);

    await tester.tap(find.byKey(const Key('contacts-disclosure-decline')));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
    expect(calls, ['permissions.check']);
  });

  testWidgets('closing the page without an answer reads nothing', (
    tester,
  ) async {
    final answer = await ask(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(await answer, isFalse);
  });

  testWidgets('once Android has the permission the page is not shown again', (
    tester,
  ) async {
    status = 'granted';
    final answer = await ask(tester);

    expect(find.byKey(const Key('contacts-disclosure')), findsNothing);
    expect(await answer, isTrue);
  });
}
