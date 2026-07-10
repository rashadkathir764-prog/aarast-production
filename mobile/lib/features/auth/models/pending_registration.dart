class PendingProviderApplication {
  const PendingProviderApplication({
    required this.businessName,
    required this.phone,
    required this.cityId,
    required this.categoryId,
    required this.description,
  });

  final String businessName;
  final String phone;
  final String cityId;
  final String categoryId;
  final String description;
}

/// Kept in navigation memory only while the user owns the OTP challenge.
/// It is never written to local storage, logs, or route query parameters.
class PendingRegistration {
  const PendingRegistration({
    required this.name,
    required this.phone,
    required this.password,
    this.email,
    this.providerApplication,
  });

  final String name;
  final String phone;
  final String password;
  final String? email;
  final PendingProviderApplication? providerApplication;
}
