class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'customer',
    this.phone = '',
    this.address = '',
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String phone;
  final String address;
  final String? avatarUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final firstName = (json['first_name'] ?? '').toString().trim();
    final lastName = (json['last_name'] ?? '').toString().trim();
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');
    return AppUser(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      name:
          (json['name'] ??
                  json['fullName'] ??
                  json['userName'] ??
                  (fullName.isNotEmpty ? fullName : json['username'] ?? ''))
              .toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'customer').toString(),
      phone: (json['phone'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'phone': phone,
    'address': address,
    'avatarUrl': avatarUrl,
  };
}
