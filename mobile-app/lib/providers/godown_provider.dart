import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/godown.dart';
import '../services/godown_service.dart';
import 'auth_provider.dart';

/// Owner godown list/detail state. Backend returns only the caller's own
/// godowns; 401 triggers logout via [AuthProvider].
class GodownProvider extends ChangeNotifier {
  final GodownService _service;
  final AuthProvider _auth;

  GodownProvider(this._service, this._auth);

  List<Godown> godowns = [];
  Godown? selected;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  Future<void> loadGodowns() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      godowns = await _service.list();
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _auth.handleUnauthorized();
      errorMessage = e.displayMessage;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDetail(String id) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      selected = await _service.getById(id);
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _auth.handleUnauthorized();
      errorMessage = e.displayMessage;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create({required String name, required String location, required double capacity}) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final created = await _service.create(name: name, location: location, capacity: capacity);
      godowns = [created, ...godowns];
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

  Future<bool> update(String id, {String? name, String? location, double? capacity}) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final updated = await _service.update(id, name: name, location: location, capacity: capacity);
      godowns = godowns.map((g) => g.id == id ? updated : g).toList();
      if (selected?.id == id) selected = updated;
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

  /// Returns false with [errorMessage] set on 409 (has inventory) etc.
  Future<bool> remove(String id) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _service.delete(id);
      godowns = godowns.where((g) => g.id != id).toList();
      if (selected?.id == id) selected = null;
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
