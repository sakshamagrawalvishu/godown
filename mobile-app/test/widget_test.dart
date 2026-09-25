import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:godown_app/core/api_client.dart';
import 'package:godown_app/main.dart';
import 'package:godown_app/models/app_user.dart';
import 'package:godown_app/providers/auth_provider.dart';
import 'package:godown_app/providers/godown_provider.dart';
import 'package:godown_app/routes/app_router.dart';
import 'package:godown_app/services/godown_service.dart';

/// Minimal fake backend: empty godown list, valid envelope.
class _FakeHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(jsonEncode({
      'success': true,
      'data': {'godowns': []},
    }));
    return http.StreamedResponse(Stream.value(bytes), 200,
        headers: {'content-type': 'application/json'});
  }
}

AuthProvider _harnessAuth({required String? role}) {
  final api = ApiClient(
      httpClient: _FakeHttpClient(), tokenProvider: () async => 'test-token');
  final auth = AuthProvider(apiClient: api);
  if (role == null) {
    auth.status = AuthStatus.unauthenticated;
  } else {
    auth.user = AppUser.fromJson({
      'id': 'u1',
      'name': 'Test User',
      'email': 'u@test.local',
      'role': role,
      'isActive': true,
    });
    auth.status = AuthStatus.authenticated;
  }
  return auth;
}

/// Pumps the real router with a controlled auth state (bypasses bootstrap,
/// whose secure-storage read never resolves in widget tests).
Future<void> _pumpHarness(WidgetTester tester, AuthProvider auth) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(
          create: (_) => GodownProvider(GodownService(auth.apiClient), auth),
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp.router(
          routerConfig: buildRouter(context.read<AuthProvider>()),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('App boots to splash/login flow', (WidgetTester tester) async {
    await tester.pumpWidget(const GodownApp());
    await tester.pump();
    // Splash shows while the stored token is validated.
    expect(find.text('Godown Management'), findsWidgets);
  });

  testWidgets('Unauthenticated users land on login, no registration link',
      (WidgetTester tester) async {
    await _pumpHarness(tester, _harnessAuth(role: null));

    expect(find.text('Log in'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
    // Public "Register as Owner" onboarding was removed (backend lockdown:
    // POST /api/auth/register rejects role OWNER with 403).
    expect(find.textContaining('Register'), findsNothing);
    expect(find.textContaining('register'), findsNothing);
  });

  testWidgets('Authenticated owner reaches dashboard',
      (WidgetTester tester) async {
    await _pumpHarness(tester, _harnessAuth(role: 'OWNER'));

    expect(find.text('Owner Dashboard'), findsOneWidget);
    // Owner-only shortcut is present.
    expect(find.text('Staff Management'), findsOneWidget);
  });

  testWidgets('Authenticated staff reaches dashboard without owner actions',
      (WidgetTester tester) async {
    await _pumpHarness(tester, _harnessAuth(role: 'STAFF'));

    expect(find.text('Owner Dashboard'), findsOneWidget);
    // No owner-only entry points for staff.
    expect(find.text('Staff Management'), findsNothing);
    expect(find.text('Godown'), findsNothing);
  });

  test('No public /register route is registered', () {
    final auth = _harnessAuth(role: null);
    final router = buildRouter(auth);

    expect(router.configuration.findMatch(Uri.parse('/register')).matches,
        isEmpty);
    // Core entry points still exist.
    expect(router.configuration.findMatch(Uri.parse('/login')).matches,
        isNotEmpty);
    expect(router.configuration.findMatch(Uri.parse('/dashboard')).matches,
        isNotEmpty);
  });

  test('Logout returns to unauthenticated state', () async {
    final auth = _harnessAuth(role: 'OWNER');
    expect(auth.isAuthenticated, isTrue);

    await auth.logout();

    expect(auth.isAuthenticated, isFalse);
    expect(auth.user, isNull);
    expect(auth.status, AuthStatus.unauthenticated);
  });
}
