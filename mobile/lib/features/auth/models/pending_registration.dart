/// Kept in navigation memory only while the user owns the OTP challenge.
/// It is never written to local storage, logs, or route query parameters.
class PendingRegistration {
  const PendingRegistration({
    required this.name,
    required this.phone,
    required this.password,
  });

  final String name;
  final String phone;
  final String password;
}
