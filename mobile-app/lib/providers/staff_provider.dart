import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/app_user.dart';
import '../services/staff_service.dart';
import 'auth_provider.dart';

/// Owner staff list/create state. Follows [GodownProvider] conventions:
/// [isLoading] for list/refresh, [isSaving] for create, [errorMessage] for
/// the screens' ErrorView/snackbar, 401 triggers logout via [AuthProvider].
/// Backend remains authoritative: STAFF tokens get 403 on these endpoints.
class StaffProvider extends ChangeNotifier {
  final StaffService _service;
  final AuthProvider _auth;

  StaffProvider(this._service, this._auth);

  List<AppUser> staff = [];
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  Future<void> loadStaff() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      staff = await _service.getStaff();
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _auth.handleUnauthorized();
      errorMessage = e.displayMessage;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createStaff({
    required String name,
    required String email,
    required String password,
  }) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final created = await _service.createStaff(
        name: name,
        email: email,
        password: password,
      );
      staff = [created, ...staff];
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _auth.handleUnauthorized();
      errorMessage = e.displayMessage;
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
