import '../../core/phone/phone_number_utils.dart';

enum ContactPhoneSource { manual, deviceContact, planContact }

class ContactPhoneDraft {
  const ContactPhoneDraft({
    required this.name,
    required this.rawPhone,
    required this.normalizedPhone,
    required this.displayPhone,
    required this.source,
    required this.validationState,
    this.relation,
    this.validationMessage,
  });

  factory ContactPhoneDraft.fromInput({
    required String name,
    required String rawPhone,
    ContactPhoneSource source = ContactPhoneSource.manual,
    String? relation,
    bool requireYemeni = false,
  }) {
    final analysis = PhoneNumberUtils.analyze(
      rawPhone,
      requireYemeni: requireYemeni,
    );
    return ContactPhoneDraft(
      name: name.trim(),
      rawPhone: rawPhone.trim(),
      normalizedPhone: analysis.normalizedPhone,
      displayPhone: analysis.displayPhone,
      source: source,
      relation: relation?.trim(),
      validationState: analysis.validationState,
      validationMessage: analysis.message,
    );
  }

  final String name;
  final String rawPhone;
  final String? normalizedPhone;
  final String? displayPhone;
  final ContactPhoneSource source;
  final String? relation;
  final PhoneValidationState validationState;
  final String? validationMessage;
}
