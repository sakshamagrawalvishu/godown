import '../core/api_client.dart';
import '../core/api_config.dart';
import '../models/app_user.dart';

/// Auth endpoints (backend/src/routes/auth.routes.js + auth.controller.js):
/// - POST /api/auth/register {name,email,password,role} -> {token,user}
/// - POST /api/auth/login {email,password} -> {token,user}
/// - GET  /api/auth/me -> {user}
class AuthService {
  final ApiClient _api;
  AuthService(this._api);

  Future<({String token, AppUser user})> register({
    required String name,
    required String email,
    required String password,
    String role = 'OWNER',
  }) async {
    final json = await _api.post(ApiConfig.register, {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
    });
    return _parseAuth(json);
  }

  Future<({String token, AppUser user})> login({
    required String email,
    required String password,
  }) async {
    final json = await _api.post(ApiConfig.login, {
      'email': email,
      'password': password,
    });
    return _parseAuth(json);
  }

  Future<AppUser> me() async {
    final json = await _api.get(ApiConfig.me);
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return AppUser.fromJson(data['user'] as Map<String, dynamic>? ?? {});
  }

  ({String token, AppUser user}) _parseAuth(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final token = (data['token'] ?? '').toString();
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>? ?? {});
    if (token.isEmpty || user.id.isEmpty) {
      throw StateError('Malformed auth response from server.');
    }
    return (token: token, user: user);
  }
}
