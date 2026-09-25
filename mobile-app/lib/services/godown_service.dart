import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/godown.dart';

/// Godown endpoints (backend/src/routes/godown.routes.js):
/// POST /api/godowns {name,location,capacity} | GET /api/godowns
/// GET|PUT|DELETE /api/godowns/:id  (PUT: {name?,location?,capacity?})
/// 404 also means "another owner's godown" (backend IDOR guard).
class GodownService {
  final ApiClient _api;
  GodownService(this._api);

  Future<List<Godown>> list() async {
    final json = await _api.get(ApiConfig.godowns);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final list = data['godowns'] as List? ?? [];
    return list.whereType<Map<String, dynamic>>().map(Godown.fromJson).toList();
  }

  Future<Godown> getById(String id) async {
    final json = await _api.get(ApiConfig.godownById(id));
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return Godown.fromJson(data['godown'] as Map<String, dynamic>? ?? {});
  }

  Future<Godown> create({required String name, required String location, required double capacity}) async {
    final json = await _api.post(ApiConfig.godowns, {
      'name': name,
      'location': location,
      'capacity': capacity,
    });
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return Godown.fromJson(data['godown'] as Map<String, dynamic>? ?? {});
  }

  Future<Godown> update(String id, {String? name, String? location, double? capacity}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (location != null) body['location'] = location;
    if (capacity != null) body['capacity'] = capacity;
    final json = await _api.put(ApiConfig.godownById(id), body);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return Godown.fromJson(data['godown'] as Map<String, dynamic>? ?? {});
  }

  Future<void> delete(String id) async {
    await _api.delete(ApiConfig.godownById(id));
  }
}
