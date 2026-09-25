/// Backend user shape: backend User.toSafeJSON() + JWT role.
/// STAFF accounts carry `owner` (owning OWNER id); OWNER accounts have null.
class AppUser {
  final String id;
  final String name;
  final String email;
  final String role; // OWNER | STAFF
  final String? owner;
  final bool isActive;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.owner,
    this.isActive = true,
  });

  bool get isOwner => role.toUpperCase() == 'OWNER';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'STAFF').toString().toUpperCase(),
      owner: json['owner']?.toString(),
      isActive: json['isActive'] is bool ? json['isActive'] as bool : true,
    );
  }
}
