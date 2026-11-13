import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../shared/models/contact_phone_draft.dart';
import '../phone/yemeni_phone_normalizer.dart';
import '../widgets/aarast_bottom_sheet.dart';
import '../widgets/aarast_phone_text.dart';
import '../experience_v3/aarast_journey.dart';
import '../experience_v3/aarast_journey_sheet.dart';
import '../experience_v3/aarast_v3_foundations.dart';

class ContactPickerException implements Exception {
  const ContactPickerException(this.message, {this.needsSettings = false});

  final String message;

  /// RA-MO-224: the permission was refused for good («لا تسأل مرة ثانية»,
  /// or a policy): asking again shows nothing, only the phone's settings
  /// open it.
  final bool needsSettings;

  @override
  String toString() => message;
}

class ContactPickerService {
  const ContactPickerService._();

  /// Only Android and iOS phones have an address book to read.
  static bool get isAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// D112 (Q-10): the app's own page before Android's question. It says
  /// what is read (names and numbers, on the phone) and what is kept (only
  /// who the person picks), and the read goes on only on a yes. Play
  /// requires this for `READ_CONTACTS`; the app went straight to the system
  /// prompt. Not shown again once the permission is held.
  ///
  /// True when the address book may be read now.
  static Future<bool> confirmAccess(BuildContext context) async {
    if (await FlutterContacts.permissions.has(PermissionType.read)) {
      return true;
    }
    if (!context.mounted) return false;
    final agreed = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        key: const Key('contacts-disclosure'),
        title: 'نقرأ جهات الاتصال من جوالك',
        subtitle:
            'عشان تنضاف الأسماء من جوالك بدل كتابتها. نقرأ الأسماء والأرقام '
            'على الجوال نفسه، وما ينحفظ في الخطة إلا من يُختار منها. دفتر '
            'الأسماء ما يطلع من جوالك.',
        children: [
          JourneyButton(
            key: const Key('contacts-disclosure-agree'),
            label: 'موافق، كمّل',
            icon: LucideIcons.contact,
            large: true,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton(
            key: const Key('contacts-disclosure-decline'),
            label: 'مو الآن',
            background: AarastV3Color.paper,
            foreground: AarastV3Color.ink,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    return agreed == true;
  }

  /// One contact by the system's picker; null when the person picked none
  /// or said «مو الآن» to the page above.
  static Future<ContactPhoneDraft?> pickContact(BuildContext context) async {
    if (!await confirmAccess(context)) return null;
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (!_isGranted(permission)) throw _refused(permission);

    final contact = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    if (contact == null) return null;

    final phones = _phoneNumbers(contact);
    if (phones.isEmpty) {
      throw const ContactPickerException('ما في رقم جوال لهذا الاسم');
    }

    String? selectedPhone;
    if (phones.length == 1) {
      selectedPhone = phones.first;
    } else {
      if (!context.mounted) return null;
      selectedPhone = await _selectPhone(context, phones);
    }
    if (selectedPhone == null) return null;

    return ContactPhoneDraft.fromInput(
      name: contact.displayName ?? '',
      rawPhone: selectedPhone,
      source: ContactPhoneSource.deviceContact,
    );
  }

  /// Every contact with a number, by name (e03). The first number of each
  /// is kept; a contact without one is left out.
  static Future<List<ContactPhoneDraft>> loadAll() async {
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (!_isGranted(permission)) throw _refused(permission);
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    final drafts = <ContactPhoneDraft>[
      for (final contact in contacts)
        // RA-MO-217: a contact saved with no name was listed as a blank
        // row, taken by «اختر الكل», and refused by the server.
        if (_phoneNumbers(contact).isNotEmpty &&
            (contact.displayName ?? '').trim().isNotEmpty)
          ContactPhoneDraft.fromInput(
            name: contact.displayName!.trim(),
            rawPhone: preferredContactPhone(_phoneNumbers(contact)),
            source: ContactPhoneSource.deviceContact,
          ),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return drafts;
  }

  /// RA-MO-216: the number of a contact to invite by: the first Yemeni
  /// mobile among its numbers, else the first. The first was always taken,
  /// so a contact whose first number is a landline was added «بدون رقم»
  /// while their mobile sat on the same card.
  @visibleForTesting
  static String preferredContactPhone(List<String> phones) =>
      phones.firstWhere(isValidYemeniPhoneInput, orElse: () => phones.first);

  static Future<String?> pickPhoneNumber(BuildContext context) async {
    final contact = await pickContact(context);
    return contact?.normalizedPhone ?? contact?.rawPhone;
  }

  static Future<String?> _selectPhone(
    BuildContext context,
    List<String> phones,
  ) {
    return showAarastBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AarastV3Space.x5,
                AarastV3Space.x3,
                AarastV3Space.x5,
                AarastV3Space.x4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'اختر رقم الجوال',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: AarastV3Space.x2),
                  for (final phone in phones)
                    ListTile(
                      leading: const Icon(LucideIcons.phone),
                      title: AarastPhoneText(phone: phone),
                      onTap: () => Navigator.of(sheetContext).pop(phone),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static bool _isGranted(PermissionStatus status) {
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  /// The refusal as said to the person (RA-MO-224).
  static ContactPickerException _refused(PermissionStatus status) {
    final forGood =
        status == PermissionStatus.permanentlyDenied ||
        status == PermissionStatus.restricted;
    return forGood
        ? const ContactPickerException(
            'إذن جهات الاتصال مقفول في جوالك. تفتحه من إعدادات الجوال.',
            needsSettings: true,
          )
        : const ContactPickerException('ما سمحت لنا نشوف جهات الاتصال');
  }

  /// The phone's settings page for this app (RA-MO-224).
  static Future<void> openSettings() =>
      FlutterContacts.permissions.openSettings();

  static List<String> _phoneNumbers(Contact contact) {
    final seen = <String>{};
    final phones = <String>[];
    for (final phone in contact.phones) {
      final raw = phone.normalizedNumber?.trim().isNotEmpty == true
          ? phone.normalizedNumber!
          : phone.number;
      final value = raw.trim();
      if (value.isEmpty || !seen.add(value)) continue;
      phones.add(value);
    }
    return phones;
  }
}

String contactPickerErrorMessage(Object error) {
  if (error is ContactPickerException) return error.message;
  if (error is PlatformException) {
    return 'ما قدرنا نفتح جهات الاتصال';
  }
  return 'ما قدرنا ناخذ رقم من جهات الاتصال';
}
