// Integration test hitting the real backend (default port 5000).
// Run: flutter test --dart-define=API_BASE_URL=http://localhost:5000
// Uses the app's own ApiClient + services, so paths/payloads are exactly
// what the UI sends.
import 'package:flutter_test/flutter_test.dart';
import 'package:godown_app/core/api_client.dart';
import 'package:godown_app/core/api_exception.dart';
import 'package:godown_app/services/auth_service.dart';
import 'package:godown_app/services/godown_service.dart';
import 'package:godown_app/services/inventory_service.dart';

void main() {
  test('owner isolation via app services', () async {
    String? token;
    final api = ApiClient(tokenProvider: () async => token);
    final auth = AuthService(api);
    final ts = DateTime.now().millisecondsSinceEpoch;

    // Register two owners.
    final regA = await auth.register(
      name: 'App Owner A',
      email: 'appA.$ts@test.local',
      password: 'Password1',
      role: 'OWNER',
    );
    final regB = await auth.register(
      name: 'App Owner B',
      email: 'appB.$ts@test.local',
      password: 'Password1',
      role: 'OWNER',
    );
    expect(regA.token, isNotEmpty);
    expect(regB.token, isNotEmpty);

    // me() with owner A token.
    token = regA.token;
    final me = await auth.me();
    expect(me.email, contains('appa'));

    // Each owner creates a godown through the app service.
    final godownsA = GodownService(api);
    final gA = await godownsA.create(name: 'App Godown A', location: 'City A', capacity: 100);
    expect(gA.ownerId, isNotNull);

    token = regB.token;
    final gB = await godownsA.create(name: 'App Godown B', location: 'City B', capacity: 50);

    // Owner B lists -> only own godown.
    final listB = await godownsA.list();
    expect(listB.length, 1);
    expect(listB.first.id, gB.id);

    // Owner B reads Owner A's godown -> 404 (IDOR guard).
    try {
      await godownsA.getById(gA.id);
      fail('expected 404');
    } on ApiException catch (e) {
      expect(e.isNotFound, isTrue);
    }

    // Owner A inventory CRUD in own godown.
    token = regA.token;
    final inv = InventoryService(api);
    final item = await inv.create(
      itemName: 'Rice',
      quantity: 10,
      unit: 'bags',
      godownId: gA.id,
    );
    expect(item.id, isNotEmpty);
    final itemsA = await inv.list(godownId: gA.id);
    expect(itemsA.length, 1);

    // Owner B cannot touch Owner A's item.
    token = regB.token;
    try {
      await InventoryService(api).create(
        itemName: 'Hack',
        quantity: 1,
        unit: 'bags',
        godownId: gA.id,
      );
      fail('expected 404');
    } on ApiException catch (e) {
      expect(e.isNotFound, isTrue);
    }

    // Bad token -> 401 (session-expired path in UI).
    token = 'invalid.token.here';
    try {
      await auth.me();
      fail('expected 401');
    } on ApiException catch (e) {
      expect(e.isUnauthorized, isTrue);
    }

    // Cleanup with rightful owners.
    token = regA.token;
    await InventoryService(api).delete(item.id);
    await GodownService(api).delete(gA.id);
    token = regB.token;
    await GodownService(api).delete(gB.id);
    api.close();
  });
}
