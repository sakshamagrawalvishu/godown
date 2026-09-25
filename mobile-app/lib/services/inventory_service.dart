import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/inventory_item.dart';

/// Inventory endpoints (backend `inventory.routes.js`):
/// `POST /api/inventory` with item fields,
/// `GET /api/inventory` with godown filter, item routes by id.
/// Access is validated through the parent godown's ownership (backend),
/// so cross-owner ids yield 404.
class InventoryService {
  final ApiClient _api;
  InventoryService(this._api);

  Future<List<InventoryItem>> list({String? godownId}) async {
    final json = await _api.get(
      ApiConfig.inventory,
      query: godownId == null ? null : {'godown': godownId},
    );
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final list = data['items'] as List? ?? [];
    return list.whereType<Map<String, dynamic>>().map(InventoryItem.fromJson).toList();
  }

  Future<InventoryItem> create({
    required String itemName,
    required double quantity,
    required String unit,
    required String godownId,
  }) async {
    final json = await _api.post(ApiConfig.inventory, {
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'godown': godownId,
    });
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return InventoryItem.fromJson(data['item'] as Map<String, dynamic>? ?? {});
  }

  Future<InventoryItem> update(
    String id, {
    String? itemName,
    double? quantity,
    String? unit,
    String? godownId,
  }) async {
    final body = <String, dynamic>{};
    if (itemName != null) body['itemName'] = itemName;
    if (quantity != null) body['quantity'] = quantity;
    if (unit != null) body['unit'] = unit;
    if (godownId != null) body['godown'] = godownId;
    final json = await _api.put(ApiConfig.inventoryById(id), body);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return InventoryItem.fromJson(data['item'] as Map<String, dynamic>? ?? {});
  }

  Future<void> delete(String id) async {
    await _api.delete(ApiConfig.inventoryById(id));
  }
}
