class SafeUser {
  const SafeUser({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    this.phone,
    this.email,
  });

  factory SafeUser.fromJson(Map<String, dynamic> json) {
    return SafeUser(
      id: json['id'].toString(),
      name: json['name'].toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      role: json['role'].toString(),
      status: json['status'].toString(),
    );
  }

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String role;
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'status': status,
    };
  }
}
