/// Backend InventoryItem shape (backend/src/models/InventoryItem.js).
/// `godown` may be an id string or a populated {name,location} map.
class InventoryItem {
  final String id;
  final String itemName;
  final double quantity;
  final String unit;
  final String godownId;
  final String? godownName;

  const InventoryItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.godownId,
    this.godownName,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final godown = json['godown'];
    String godownId = '';
    String? godownName;
    if (godown is String) {
      godownId = godown;
    } else if (godown is Map) {
      godownId = (godown['_id'] ?? '').toString();
      godownName = godown['name']?.toString();
    }
    return InventoryItem(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      itemName: (json['itemName'] ?? '').toString(),
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toDouble() : 0,
      unit: (json['unit'] ?? '').toString(),
      godownId: godownId,
      godownName: godownName,
    );
  }
}
