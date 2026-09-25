import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/app_user.dart';

/// Staff management endpoints (backend `user.routes.js` + `user.controller.js`):
/// POST /api/users {name,email,password} -> {user} (OWNER only, STAFF role forced)
/// GET /api/users?role=STAFF -> {users} (OWNER only, scoped to caller's staff)
/// Backend authorization is authoritative; the UI additionally hides these
/// actions from STAFF users (see screens + router guards).
class StaffService {
  final ApiClient _api;
  StaffService(this._api);

  /// Owner creates a STAFF account. Backend rejects non-STAFF roles here.
  Future<AppUser> createStaff({
    required String name,
    required String email,
    required String password,
  }) async {
    final json = await _api.post(ApiConfig.users, {
      'name': name,
      'email': email,
      'password': password,
    });
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return AppUser.fromJson(data['user'] as Map<String, dynamic>? ?? {});
  }

  /// Owner lists only their own staff. Always filters by role=STAFF so the
  /// OWNER-self shortcut (`?role=OWNER`) is never used here.
  Future<List<AppUser>> getStaff() async {
    final json = await _api.get(ApiConfig.users, query: {'role': 'STAFF'});
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final list = data['users'] as List? ?? [];
    return list.whereType<Map<String, dynamic>>().map(AppUser.fromJson).toList();
  }
}
