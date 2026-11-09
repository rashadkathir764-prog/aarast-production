import 'package:aarast_mobile/core/forms/aarast_form_draft_store.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_form_sheet.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('guest form returns normalized product data', (tester) async {
    GuestFormResult? result;
    await _openForm(tester, onResult: (value) => result = value);

    await tester.enterText(_name, 'سالم أحمد');
    await tester.enterText(_phone, '777654321');
    await tester.tap(find.byKey(const ValueKey('guest-form-more')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('guest-form-notes')),
      'من العائلة',
    );
    await _submit(tester);

    expect(result, isNotNull);
    expect(result!.name, 'سالم أحمد');
    expect(result!.phone, '+967777654321');
    expect(result!.side, 'OTHER');
    expect(result!.status, 'INVITED');
    expect(result!.seatsCount, 1);
    expect(result!.companionsCount, 0);
    expect(result!.notes, 'من العائلة');
    expect(result!.addAnother, isFalse);
  });

  testWidgets('guest form keeps validation inside the sheet', (tester) async {
    GuestFormResult? result;
    await _openForm(tester, onResult: (value) => result = value);

    await _submit(tester);
    expect(find.text('اكتب اسمه'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(_name, 'ضيف');
    await tester.enterText(_phone, '123');
    await _submit(tester);

    expect(
      find.byKey(const ValueKey('guest-form-phone-error')),
      findsOneWidget,
    );
    expect(result, isNull);
  });

  testWidgets('a bride adding to the groom\'s list: her verb, his guest', (
    tester,
  ) async {
    await _openForm(
      tester,
      profile: JourneyProfile.of(
        planPersona: 'GROOM',
        readerFeminine: true,
        readerIsOwner: false,
      ),
      onResult: (_) {},
    );

    await _submit(tester);
    // She is spoken to; the guest is the groom's plan's.
    expect(find.text('اكتبي اسمه'), findsOneWidget);
    expect(find.text('كم معه؟'), findsOneWidget);
  });

  testWidgets('cloud form blocks a duplicate phone', (tester) async {
    GuestFormResult? result;
    await _openForm(
      tester,
      existingGuests: [_guest(phone: '+967777123456')],
      blockDuplicatePhone: true,
      onResult: (value) => result = value,
    );

    await tester.enterText(_name, 'ضيف آخر');
    await tester.enterText(_phone, '777123456');
    await _submit(tester);

    expect(find.text('رقمه عندك لـضيف موجود'), findsWidgets);
    expect(result, isNull);
  });

  testWidgets('local form allows an intentional duplicate phone', (
    tester,
  ) async {
    GuestFormResult? result;
    await _openForm(
      tester,
      existingGuests: [_guest(phone: '+967777123456')],
      blockDuplicatePhone: false,
      onResult: (value) => result = value,
    );

    await tester.enterText(_name, 'ضيف آخر');
    await tester.enterText(_phone, '777123456');
    await _submit(tester);

    expect(result, isNotNull);
    expect(result!.phone, '+967777123456');
  });

  testWidgets('edit form preserves values and companion-seat invariant', (
    tester,
  ) async {
    GuestFormResult? result;
    const group = GuestGroup(
      id: 'group-1',
      weddingPlanId: 'plan-1',
      name: 'العائلة',
    );
    await _openForm(
      tester,
      guest: _guest(
        phone: '+967777123456',
        groupId: group.id,
        side: 'GROOM',
        status: 'CONFIRMED',
      ),
      groups: const [group],
      onResult: (value) => result = value,
    );

    expect(find.text('تعديل ضيف'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('guest-form-group-group-1')),
      findsOneWidget,
    );
    // e06 «كم معه؟»: two with him means three seats.
    await tester.tap(find.byKey(const ValueKey('guest-form-companions-2')));
    await tester.pump();
    await _submit(tester);

    expect(result, isNotNull);
    expect(result!.groupId, group.id);
    expect(result!.side, 'GROOM');
    expect(result!.status, 'CONFIRMED');
    expect(result!.companionsCount, 2);
    expect(result!.seatsCount, 3);
  });

  // RA-MO-60: a guest and who comes with them take at most 20 seats (the
  // server's own limit), so «أكثر» stops at +19 and the save is taken.
  testWidgets('companions stop where the seats do', (tester) async {
    GuestFormResult? result;
    await _openForm(
      tester,
      guest: _guest(phone: '+967777123456'),
      onResult: (value) => result = value,
    );
    final more = find.byKey(const ValueKey('guest-form-companions-more'));
    await tester.ensureVisible(more);
    for (var tap = 0; tap < 25; tap++) {
      await tester.tap(more);
      await tester.pump();
    }
    await _submit(tester);

    expect(result, isNotNull);
    expect(result!.companionsCount, 19);
    expect(result!.seatsCount, 20);
  });

  testWidgets('a new family is made from the form and chosen', (tester) async {
    GuestFormResult? result;
    final made = <String>[];
    await _openForm(
      tester,
      onCreateGroup: (name) async {
        made.add(name);
        return 'group-new';
      },
      onResult: (value) => result = value,
    );

    await tester.enterText(_name, 'خالد الحمدي');
    await tester.tap(find.byKey(const ValueKey('guest-form-group-new')));
    await tester.pumpAndSettle();
    // «عائلة جديدة» is a journey sheet over the form, not a dialog.
    expect(find.text('عائلة جديدة'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('guest-form-group-name')),
      'آل الحمدي',
    );
    await tester.tap(find.byKey(const ValueKey('guest-form-group-create')));
    await tester.pumpAndSettle();
    expect(find.text('آل الحمدي'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('guest-form-save-next')));
    await tester.pumpAndSettle();

    expect(made, ['آل الحمدي']);
    expect(result!.groupId, 'group-new');
    expect(result!.addAnother, isTrue);
  });

  testWidgets('V-02: the draft line waits until something is typed', (
    tester,
  ) async {
    const scope = 'guest:plan-1:new';
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(await SharedPreferences.getInstance());
    final store = AarastFormDraftStore(vault: _Vault(), authStorage: storage);
    await _openForm(
      tester,
      draftStore: store,
      draftScope: scope,
      onResult: (_) {},
    );

    // An empty form has nothing saved, so it claims nothing.
    expect(find.textContaining('المسودة'), findsNothing);
    expect(find.textContaining('ستُحفظ'), findsNothing);

    await tester.enterText(_name, 'سالم');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    // RA-MO-27: a draft on the phone, never «saved» for the guest itself.
    expect(find.text('المسودة محفوظة على جوالك'), findsOneWidget);
  });

  // A name saved within the autosave's half second came back in the next
  // form: the sheet wrote its draft after the list had cleared it.
  testWidgets('a saved guest leaves no draft for the next one', (tester) async {
    const scope = 'guest:plan-1:new';
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(await SharedPreferences.getInstance());
    final store = AarastFormDraftStore(vault: _Vault(), authStorage: storage);
    await _openForm(
      tester,
      draftStore: store,
      draftScope: scope,
      onResult: (_) => store.clear(scope),
    );

    await tester.enterText(_name, 'سالم أحمد');
    await tester.tap(find.byKey(const ValueKey('guest-form-save-next')));
    await tester.pumpAndSettle();

    expect(await store.read(scope), isNull);
  });
}

class _Vault implements SensitiveValueVault {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

Future<void> _openForm(
  WidgetTester tester, {
  Guest? guest,
  List<Guest> existingGuests = const [],
  List<GuestGroup> groups = const [],
  bool blockDuplicatePhone = true,
  Future<String?> Function(String name)? onCreateGroup,
  AarastFormDraftStore? draftStore,
  String? draftScope,
  JourneyProfile profile = JourneyProfile.groom,
  required ValueChanged<GuestFormResult?> onResult,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    Provider<AarastFormDraftStore?>.value(
      value: draftStore,
      child: MaterialApp(
        builder: (context, child) =>
            JourneyProfileScope(profile: profile, child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                final result = await showAarastBottomSheet<GuestFormResult>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => GuestFormSheet(
                    guest: guest,
                    existingGuests: existingGuests,
                    groups: groups,
                    blockDuplicatePhone: blockDuplicatePhone,
                    onCreateGroup: onCreateGroup,
                    draftScope: draftScope,
                  ),
                );
                onResult(result);
              },
              child: const Text('فتح'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('فتح'));
  await tester.pumpAndSettle();
}

final _name = find.byKey(const ValueKey('guest-form-name'));
final _phone = find.descendant(
  of: find.byKey(const ValueKey('guest-form-phone')),
  matching: find.byType(EditableText),
);

Future<void> _submit(WidgetTester tester) async {
  final submit = find.byKey(const ValueKey('guest-form-save'));
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

Guest _guest({
  String? phone,
  String? groupId,
  String side = 'OTHER',
  String status = 'INVITED',
}) {
  final now = DateTime.utc(2026, 7, 11);
  return Guest(
    id: 'guest-1',
    weddingPlanId: 'plan-1',
    name: 'ضيف موجود',
    phone: phone,
    groupId: groupId,
    side: side,
    status: status,
    seatsCount: 1,
    createdAt: now,
    updatedAt: now,
  );
}
