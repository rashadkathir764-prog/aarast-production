import 'package:aarast_mobile/core/phone/phone_number_utils.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('guest form returns normalized product data', (tester) async {
    GuestFormResult? result;
    await _openForm(tester, onResult: (value) => result = value);

    await tester.enterText(_fieldWithLabel('اسم الضيف'), 'سالم أحمد');
    await tester.enterText(_fieldWithLabel('رقم الجوال'), '777654321');
    await tester.tap(find.text('تفاصيل إضافية'));
    await tester.pumpAndSettle();
    await tester.enterText(_fieldWithLabel('ملاحظة قصيرة'), 'من العائلة');
    await _submit(tester, 'إضافة ضيف');

    expect(result, isNotNull);
    expect(result!.name, 'سالم أحمد');
    expect(result!.phone, '+967777654321');
    expect(result!.side, 'OTHER');
    expect(result!.status, 'INVITED');
    expect(result!.seatsCount, 1);
    expect(result!.companionsCount, 0);
    expect(result!.notes, 'من العائلة');
  });

  testWidgets('guest form keeps validation inside the sheet', (tester) async {
    GuestFormResult? result;
    await _openForm(tester, onResult: (value) => result = value);

    await _submit(tester, 'إضافة ضيف');
    expect(find.text('اسم الضيف مطلوب'), findsOneWidget);
    expect(result, isNull);

    await tester.enterText(_fieldWithLabel('اسم الضيف'), 'ضيف');
    await tester.enterText(_fieldWithLabel('رقم الجوال'), '123');
    await _submit(tester, 'إضافة ضيف');

    expect(find.text(PhoneNumberUtils.invalidMessage), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('cloud form blocks a duplicate phone', (tester) async {
    GuestFormResult? result;
    await _openForm(
      tester,
      existingGuests: [_guest(phone: '+967777123456')],
      blockDuplicatePhone: true,
      onResult: (value) => result = value,
    );

    await tester.enterText(_fieldWithLabel('اسم الضيف'), 'ضيف آخر');
    await tester.enterText(_fieldWithLabel('رقم الجوال'), '777123456');
    await _submit(tester, 'إضافة ضيف');

    expect(find.text('هذا الضيف موجود مسبقًا'), findsWidgets);
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

    await tester.enterText(_fieldWithLabel('اسم الضيف'), 'ضيف آخر');
    await tester.enterText(_fieldWithLabel('رقم الجوال'), '777123456');
    await _submit(tester, 'إضافة ضيف');

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
    expect(find.text('العائلة'), findsOneWidget);
    final plusButtons = find.byTooltip('زيادة العدد');
    await tester.tap(plusButtons.at(1));
    await tester.pump();
    await tester.tap(plusButtons.at(1));
    await tester.pump();
    await _submit(tester, 'حفظ التعديل');

    expect(result, isNotNull);
    expect(result!.groupId, group.id);
    expect(result!.side, 'GROOM');
    expect(result!.status, 'CONFIRMED');
    expect(result!.companionsCount, 2);
    expect(result!.seatsCount, 3);
  });
}

Future<void> _openForm(
  WidgetTester tester, {
  Guest? guest,
  List<Guest> existingGuests = const [],
  List<GuestGroup> groups = const [],
  bool blockDuplicatePhone = true,
  required ValueChanged<GuestFormResult?> onResult,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
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
                ),
              );
              onResult(result);
            },
            child: const Text('فتح'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('فتح'));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester, String label) async {
  final submit = find.widgetWithText(FilledButton, label).last;
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

Finder _fieldWithLabel(String label) {
  return find
      .ancestor(of: find.text(label), matching: find.byType(TextField))
      .first;
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
