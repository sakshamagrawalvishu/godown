import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';
import 'auth_provider.dart';

/// Inventory for the selected godown. All calls are scoped server-side
/// through the parent godown's ownership.
class InventoryProvider extends ChangeNotifier {
  final InventoryService _service;
  final AuthProvider _auth;

  InventoryProvider(this._service, this._auth);

  List<InventoryItem> items = [];
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  String? godownId;

  Future<void> loadItems(String godownId) async {
    this.godownId = godownId;
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      items = await _service.list(godownId: godownId);
    } on ApiException catch (e) {
      if (e.isUnauthorized) await _auth.handleUnauthorized();
      errorMessage = e.displayMessage;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> create({
    required String itemName,
    required double quantity,
    required String unit,
    required String godownId,
  }) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final created = await _service.create(
        itemName: itemName,
        quantity: quantity,
        unit: unit,
        godownId: godownId,
      );
      items = [created, ...items];
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

  Future<bool> update(String id,
      {String? itemName, double? quantity, String? unit, String? godownId}) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final updated = await _service.update(id,
          itemName: itemName, quantity: quantity, unit: unit, godownId: godownId);
      final scoped = this.godownId;
      if (scoped != null &&
          updated.godownId.isNotEmpty &&
          updated.godownId != scoped) {
        // Item was moved to another godown: it no longer belongs to this
        // scoped list, so drop it instead of showing it under the old godown.
        items = items.where((i) => i.id != id).toList();
      } else {
        items = items.map((i) => i.id == id ? updated : i).toList();
      }
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

  Future<bool> remove(String id) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _service.delete(id);
      items = items.where((i) => i.id != id).toList();
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
