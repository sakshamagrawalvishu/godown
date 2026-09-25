/// Backend Godown shape (backend/src/models/Godown.js).
/// `owner` may be an id string or a populated {name,email} map.
class Godown {
  final String id;
  final String name;
  final String location;
  final double capacity;
  final String? ownerId;

  const Godown({
    required this.id,
    required this.name,
    required this.location,
    required this.capacity,
    this.ownerId,
  });

  factory Godown.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    String? ownerId;
    if (owner is String) {
      ownerId = owner;
    } else if (owner is Map && owner['_id'] != null) {
      ownerId = owner['_id'].toString();
    }
    return Godown(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      capacity: (json['capacity'] is num) ? (json['capacity'] as num).toDouble() : 0,
      ownerId: ownerId,
    );
  }
}
