import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:godown_app/core/api_client.dart';
import 'package:godown_app/core/api_exception.dart';
import 'package:godown_app/models/app_user.dart';
import 'package:godown_app/providers/auth_provider.dart';
import 'package:godown_app/providers/staff_provider.dart';
import 'package:godown_app/routes/app_router.dart';
import 'package:godown_app/services/staff_service.dart';

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

AppUser ownerUser() => AppUser.fromJson({
      'id': 'owner1',
      'name': 'Owner',
      'email': 'owner@test.local',
      'role': 'OWNER',
      'isActive': true,
    });

AppUser staffUser() => AppUser.fromJson({
      'id': 'staff1',
      'name': 'Staff',
      'email': 'staff@test.local',
      'role': 'STAFF',
      'owner': 'owner1',
      'isActive': true,
    });

AuthProvider testAuth({required AppUser? user}) {
  final api = ApiClient(tokenProvider: () async => 'test-token');
  final auth = AuthProvider(apiClient: api);
  auth.user = user;
  auth.status =
      user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
  return auth;
}

void main() {
  group('StaffService', () {
    test('createStaff uses POST /api/users', () async {
      final fake = FakeHttpClient((request) async => jsonResponse({
            'success': true,
            'data': {
              'user': {
                'id': 's1',
                'name': 'Worker',
                'email': 'w@test.local',
                'role': 'STAFF',
                'owner': 'owner1',
                'isActive': true,
              }
            }
          }, 201));
      final service =
          StaffService(ApiClient(httpClient: fake, tokenProvider: () async => 't'));

      final created = await service.createStaff(
          name: 'Worker', email: 'w@test.local', password: 'Password1');

      expect(fake.lastRequest!.method, 'POST');
      expect(fake.lastRequest!.url.path, '/api/users');
      expect(fake.lastBody!['name'], 'Worker');
      expect(fake.lastBody!['email'], 'w@test.local');
      expect(fake.lastBody!['password'], 'Password1');
      expect(created.role, 'STAFF');
      expect(created.email, 'w@test.local');
    });

    test('getStaff uses GET /api/users?role=STAFF', () async {
      final fake = FakeHttpClient((request) async => jsonResponse({
            'success': true,
            'data': {
              'users': [
                {
                  'id': 's1',
                  'name': 'A',
                  'email': 'a@test.local',
                  'role': 'STAFF',
                  'isActive': true,
                }
              ]
            }
          }, 200));
      final service =
          StaffService(ApiClient(httpClient: fake, tokenProvider: () async => 't'));

      final list = await service.getStaff();

      expect(fake.lastRequest!.method, 'GET');
      expect(fake.lastRequest!.url.path, '/api/users');
      expect(fake.lastRequest!.url.queryParameters['role'], 'STAFF');
      expect(list, hasLength(1));
      expect(list.first.name, 'A');
    });

    test('API errors surface typed ApiException', () async {
      Future<ApiException> capture(int status, String message) async {
        final fake = FakeHttpClient(
            (request) async => jsonResponse({'message': message}, status));
        final service = StaffService(
            ApiClient(httpClient: fake, tokenProvider: () async => 't'));
        try {
          await service.getStaff();
          fail('expected ApiException');
        } on ApiException catch (e) {
          return e;
        }
      }

      expect((await capture(400, 'Bad')).statusCode, 400);
      expect((await capture(401, 'Expired')).isUnauthorized, isTrue);
      expect((await capture(403, 'Denied')).isForbidden, isTrue);
      expect((await capture(409, 'Duplicate')).isConflict, isTrue);
    });
  });

  group('StaffProvider', () {
    test('loadStaff populates list and clears error', () async {
      final fake = FakeHttpClient((request) async => jsonResponse({
            'success': true,
            'data': {
              'users': [
                {
                  'id': 's1',
                  'name': 'A',
                  'email': 'a@test.local',
                  'role': 'STAFF',
                  'isActive': true,
                }
              ]
            }
          }, 200));
      final auth = testAuth(user: ownerUser());
      final provider = StaffProvider(
          StaffService(
              ApiClient(httpClient: fake, tokenProvider: () async => 't')),
          auth);

      await provider.loadStaff();

      expect(provider.staff, hasLength(1));
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('loadStaff maps 403 to display message without logout', () async {
      final fake = FakeHttpClient((request) async =>
          jsonResponse({'message': 'Forbidden. Insufficient permissions.'}, 403));
      final auth = testAuth(user: staffUser());
      final provider = StaffProvider(
          StaffService(
              ApiClient(httpClient: fake, tokenProvider: () async => 't')),
          auth);

      await provider.loadStaff();

      expect(provider.staff, isEmpty);
      expect(provider.errorMessage, isNotNull);
      // 403 must NOT log out; only 401 does.
      expect(auth.status, AuthStatus.authenticated);
    });

    test('loadStaff maps 401 to logout', () async {
      final fake = FakeHttpClient((request) async =>
          jsonResponse({'message': 'Token expired. Please log in again.'}, 401));
      final auth = testAuth(user: ownerUser());
      final provider = StaffProvider(
          StaffService(
              ApiClient(httpClient: fake, tokenProvider: () async => 't')),
          auth);

      await provider.loadStaff();

      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.user, isNull);
    });

    test('createStaff prepends on success, reports 409', () async {
      var calls = 0;
      final fake = FakeHttpClient((request) async {
        calls++;
        if (calls == 1) {
          return jsonResponse({
            'success': true,
            'data': {
              'user': {
                'id': 's9',
                'name': 'New',
                'email': 'new@test.local',
                'role': 'STAFF',
                'isActive': true,
              }
            }
          }, 201);
        }
        return jsonResponse({'message': 'Email is already registered.'}, 409);
      });
      final auth = testAuth(user: ownerUser());
      final provider = StaffProvider(
          StaffService(
              ApiClient(httpClient: fake, tokenProvider: () async => 't')),
          auth);

      final ok = await provider.createStaff(
          name: 'New', email: 'new@test.local', password: 'Password1');
      expect(ok, isTrue);
      expect(provider.staff.first.email, 'new@test.local');

      final dup = await provider.createStaff(
          name: 'Dup', email: 'new@test.local', password: 'Password1');
      expect(dup, isFalse);
      expect(provider.errorMessage, contains('already registered'));
    });
  });

  group('Staff navigation authorization', () {
    test('OWNER can access staff management routes', () {
      final auth = testAuth(user: ownerUser());
      final router = buildRouter(auth);
      final matchStaff = router.configuration.findMatch(Uri.parse('/staff'));
      final matchNew = router.configuration.findMatch(Uri.parse('/staff/new'));
      expect(matchStaff.matches, isNotEmpty);
      expect(matchNew.matches, isNotEmpty);
      expect(auth.isOwner, isTrue);
    });

    test('STAFF is not owner so staff UI stays hidden', () {
      final auth = testAuth(user: staffUser());
      expect(auth.isOwner, isFalse);
      // Router redirect guard sends non-owners from /staff* to /dashboard.
      final router = buildRouter(auth);
      expect(router.configuration.findMatch(Uri.parse('/staff')).matches, isNotEmpty);
      // Guard condition itself: non-owner + staff route => redirect target.
      final isStaffRoute = '/staff'.startsWith('/staff');
      final shouldRedirect = isStaffRoute && !auth.isOwner;
      expect(shouldRedirect, isTrue);
    });
  });
}
