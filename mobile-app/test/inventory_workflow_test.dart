import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:godown_app/core/api_client.dart';
import 'package:godown_app/core/api_exception.dart';
import 'package:godown_app/models/app_user.dart';
import 'package:godown_app/models/inventory_item.dart';
import 'package:godown_app/providers/auth_provider.dart';
import 'package:godown_app/providers/inventory_provider.dart';
import 'package:godown_app/services/inventory_service.dart';
import 'package:godown_app/utils/inventory_utils.dart';

/// Fake HTTP client capturing the request the app sends.
class FakeHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;
  http.BaseRequest? lastRequest;
  Map<String, dynamic>? lastBody;

  FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    if (request is http.Request && request.body.isNotEmpty) {
      try {
        lastBody = jsonDecode(request.body) as Map<String, dynamic>;
      } catch (_) {
        lastBody = null;
      }
    }
    return handler(request);
  }
}

http.StreamedResponse jsonResponse(Object json, int status) {
  final bytes = utf8.encode(jsonEncode(json));
  return http.StreamedResponse(Stream.value(bytes), status,
      headers: {'content-type': 'application/json'});
}

Map<String, dynamic> itemJson({
  String id = 'item1',
  String name = 'Rice',
  double quantity = 10,
  String unit = 'bags',
  String godown = 'g1',
}) =>
    {
      '_id': id,
      'itemName': name,
      'quantity': quantity,
      'unit': unit,
      'godown': {'_id': godown, 'name': 'Godown $godown'},
    };

InventoryItem item({
  String id = 'item1',
  String name = 'Rice',
  double quantity = 10,
  String unit = 'bags',
  String godown = 'g1',
}) =>
    InventoryItem(id: id, itemName: name, quantity: quantity, unit: unit, godownId: godown);

AuthProvider testAuth({required String role}) {
  final api = ApiClient(tokenProvider: () async => 'test-token');
  final auth = AuthProvider(apiClient: api);
  auth.user = AppUser.fromJson({
    'id': 'u1',
    'name': 'User',
    'email': 'u@test.local',
    'role': role,
    'isActive': true,
  });
  auth.status = AuthStatus.authenticated;
  return auth;
}

InventoryProvider providerWith(FakeHttpClient fake, AuthProvider auth) =>
    InventoryProvider(
        InventoryService(
            ApiClient(httpClient: fake, tokenProvider: () async => 't')),
        auth);

void main() {
  group('godown transfer', () {
    test('provider update passes godownId through to PUT body', () async {
      final fake = FakeHttpClient((request) async => jsonResponse({
            'success': true,
            'data': { 'item': itemJson(godown: 'g2') }
          }, 200));
      final provider = providerWith(fake, testAuth(role: 'OWNER'));
      provider.godownId = 'g1';

      final ok = await provider.update('item1', godownId: 'g2');

      expect(ok, isTrue);
      expect(fake.lastRequest!.method, 'PUT');
      expect(fake.lastRequest!.url.path, '/api/inventory/item1');
      expect(fake.lastBody!['godown'], 'g2');
    });

    test('moved item is dropped from the old godown scoped list', () async {
      final fake = FakeHttpClient((request) async => jsonResponse({
            'success': true,
            'data': { 'item': itemJson(id: 'item1', godown: 'g2') }
          }, 200));
      final provider = providerWith(fake, testAuth(role: 'OWNER'));
      provider.godownId = 'g1';
      provider.items = [item(), item(id: 'item2', name: 'Wheat', godown: 'g1')];

      await provider.update('item1', godownId: 'g2');

      expect(provider.items.map((i) => i.id), ['item2']);
    });

    test('same-godown update replaces the item in place', () async {
      final fake = FakeHttpClient((request) async => jsonResponse({
            'success': true,
            'data': { 'item': itemJson(id: 'item1', quantity: 99, godown: 'g1') }
          }, 200));
      final provider = providerWith(fake, testAuth(role: 'OWNER'));
      provider.godownId = 'g1';
      provider.items = [item(), item(id: 'item2', name: 'Wheat', godown: 'g1')];

      final ok = await provider.update('item1', quantity: 99);

      expect(ok, isTrue);
      expect(fake.lastBody!.containsKey('godown'), isFalse);
      expect(provider.items, hasLength(2));
      expect(provider.items.firstWhere((i) => i.id == 'item1').quantity, 99);
    });

    test('move failure (404 unknown godown) surfaces error', () async {
      final fake = FakeHttpClient((request) async =>
          jsonResponse({'message': 'Godown not found.'}, 404));
      final provider = providerWith(fake, testAuth(role: 'OWNER'));
      provider.godownId = 'g1';
      provider.items = [item()];

      final ok = await provider.update('item1', godownId: 'nope');

      expect(ok, isFalse);
      expect(provider.errorMessage, isNotNull);
      expect(provider.items, hasLength(1)); // list untouched on failure
    });
  });

  group('quantity rules', () {
    test('stepping never goes negative', () {
      expect(stepQuantity(5, -1), 4);
      expect(stepQuantity(0, -1), 0);
      expect(stepQuantity(0.5, -1), 0);
      expect(stepQuantity(0, 1), 1);
      expect(clampQuantity(-42), 0);
      expect(clampQuantity(7), 7);
    });

    test('formatQuantity trims whole numbers', () {
      expect(formatQuantity(10), '10');
      expect(formatQuantity(10.5), '10.5');
    });
  });

  group('inventory search', () {
    final items = [
      item(name: 'Basmati Rice'),
      item(id: 'item2', name: 'Wheat Flour', godown: 'g1'),
      item(id: 'item3', name: 'RICE Bran', godown: 'g1'),
    ];

    test('filters by item name, case-insensitive', () {
      final result = filterInventoryByName(items, 'rice');
      expect(result.map((i) => i.id), ['item1', 'item3']);
    });

    test('blank query returns everything', () {
      expect(filterInventoryByName(items, ''), hasLength(3));
      expect(filterInventoryByName(items, '   '), hasLength(3));
    });

    test('no match returns empty list', () {
      expect(filterInventoryByName(items, 'cement'), isEmpty);
    });
  });

  group('stock summary honesty', () {
    test('mixed units are totaled separately', () {
      final items = [
        item(name: 'A', quantity: 10, unit: 'bags'),
        item(id: 'item2', name: 'B', quantity: 5, unit: 'bags'),
        item(id: 'item3', name: 'C', quantity: 20, unit: 'kg'),
      ];
      final totals = totalsByUnit(items);
      expect(totals, {'bags': 15, 'kg': 20});
      expect(stockSummary(items), '15 bags · 20 kg');
    });

    test('empty stock shows placeholder', () {
      expect(stockSummary([]), '—');
    });
  });

  group('permissions', () {
    test('STAFF user is not owner (write actions hidden)', () {
      expect(testAuth(role: 'STAFF').isOwner, isFalse);
    });

    test('OWNER retains all inventory actions', () {
      expect(testAuth(role: 'OWNER').isOwner, isTrue);
    });

    test('STAFF write attempt surfaces 403 without logout', () async {
      final fake = FakeHttpClient((request) async =>
          jsonResponse({'message': 'Forbidden. Insufficient permissions.'}, 403));
      final auth = testAuth(role: 'STAFF');
      final provider = providerWith(fake, auth);

      final ok = await provider.remove('item1');

      expect(ok, isFalse);
      expect(provider.errorMessage, isNotNull);
      // 403 must not end the session; only 401 does.
      expect(auth.status, AuthStatus.authenticated);
    });

    test('401 maps to logout; other errors use display messages', () async {
      ApiException e403() {
        try {
          throw const ApiException(403, 'Forbidden. Insufficient permissions.');
        } on ApiException catch (e) {
          return e;
        }
      }

      // Static helper sanity: ApiException helpers used by providers.
      const e400 = ApiException(400, 'Bad');
      const e401 = ApiException(401, 'Expired');
      const e404 = ApiException(404, 'Missing');
      const e409 = ApiException(409, 'Conflict');
      const eNet = ApiException(-1, 'Down');
      expect(e400.displayMessage, 'Bad');
      expect(e401.isUnauthorized, isTrue);
      expect(e404.isNotFound, isTrue);
      expect(e409.isConflict, isTrue);
      expect(eNet.isNetworkError, isTrue);
      expect(e403().isForbidden, isTrue);
    });
  });
}
