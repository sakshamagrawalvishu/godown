import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure JWT persistence.
///
/// Uses [FlutterSecureStorage] on device; falls back to memory when the
/// platform plugin is unavailable (e.g. Linux desktop test runs) so the
/// app still works instead of crashing on startup.
class AuthStorage {
  static const _tokenKey = 'jwt_token';

  final FlutterSecureStorage _secure;
  String? _memoryFallback;
  bool _useMemory = false;

  AuthStorage({FlutterSecureStorage? secure}) : _secure = secure ?? const FlutterSecureStorage();

  Future<String?> readToken() async {
    if (_useMemory) return _memoryFallback;
    try {
      return await _secure.read(key: _tokenKey);
    } catch (_) {
      _useMemory = true;
      return _memoryFallback;
    }
  }

  Future<void> writeToken(String token) async {
    _memoryFallback = token;
    if (_useMemory) return;
    try {
      await _secure.write(key: _tokenKey, value: token);
    } catch (_) {
      _useMemory = true;
    }
  }

  Future<void> clearToken() async {
    _memoryFallback = null;
    if (_useMemory) return;
    try {
      await _secure.delete(key: _tokenKey);
    } catch (_) {
      _useMemory = true;
    }
  }
}
