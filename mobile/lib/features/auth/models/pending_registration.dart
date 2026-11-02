/// Kept in navigation memory only while the user owns the OTP challenge.
/// It is never written to local storage, logs, or route query parameters.
/// D75: the account is the number and the WhatsApp code; a password is
/// added later from the settings, if wanted.
class PendingRegistration {
  const PendingRegistration({required this.name, required this.phone});

  final String name;
  final String phone;
}
