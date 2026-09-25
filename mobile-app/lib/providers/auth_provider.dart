import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/auth_storage.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

/// Session state: token in [AuthStorage], user from GET /api/auth/me.
/// Startup: [bootstrap] validates a stored token, clears invalid ones.
/// 401 anywhere maps to [logout] (session expired).
class AuthProvider extends ChangeNotifier {
  final AuthStorage _storage;
  late final ApiClient apiClient;
  late final AuthService _service;

  AuthStatus status = AuthStatus.checking;
  AppUser? user;
  String? _token;
  String? errorMessage;
  bool busy = false;

  AuthProvider({AuthStorage? storage, ApiClient? apiClient, AuthService? authService})
      : _storage = storage ?? AuthStorage() {
    // ApiClient must read the live token for `Authorization: Bearer`.
    this.apiClient = apiClient ?? ApiClient(tokenProvider: () async => _token ?? await _storage.readToken());
    // Rebuild the service against the authenticated client.
    _service = authService ?? AuthService(this.apiClient);
  }

  AuthService get _serviceOverride => _service;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isOwner => user?.isOwner ?? false;

  Future<void> bootstrap() async {
    status = AuthStatus.checking;
    notifyListeners();
    try {
      final stored = await _storage.readToken();
      if (stored == null || stored.isEmpty) {
        status = AuthStatus.unauthenticated;
      } else {
        _token = stored;
        user = await _serviceOverride.me();
        status = AuthStatus.authenticated;
      }
    } on ApiException catch (e) {
      // Invalid/expired token -> clear and force login (401/any error).
      if (e.isUnauthorized) {
        await _storage.clearToken();
        _token = null;
        user = null;
      }
      status = AuthStatus.unauthenticated;
      errorMessage = e.displayMessage;
    } catch (_) {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _serviceOverride.login(email: email.trim(), password: password);
      _token = result.token;
      user = result.user;
      await _storage.writeToken(result.token);
      status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      errorMessage = e.displayMessage;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Retained for API completeness (the backend endpoint now creates
  /// STAFF only and rejects OWNER with 403). The app has no public
  /// registration UI: owners are seeded server-side and staff are
  /// created by owners via StaffProvider.
  Future<bool> register({required String name, required String email, required String password}) async {
    busy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final result = await _serviceOverride.register(
        name: name.trim(),
        email: email.trim(),
        password: password,
        role: 'OWNER',
      );
      _token = result.token;
      user = result.user;
      await _storage.writeToken(result.token);
      status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      errorMessage = e.displayMessage;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _storage.clearToken();
    _token = null;
    user = null;
    errorMessage = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Called by data providers on 401 to end the session.
  Future<void> handleUnauthorized() => logout();
}
