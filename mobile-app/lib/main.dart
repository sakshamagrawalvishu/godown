import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/godown_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/staff_provider.dart';
import 'routes/app_router.dart';
import 'services/godown_service.dart';
import 'services/inventory_service.dart';
import 'services/staff_service.dart';

/// Godown Management — Owner flow:
/// Splash/Auth check -> Login -> Dashboard -> My Godowns
/// -> Create/Edit Godown -> Details -> Inventory CRUD.
///
/// Backend base URL defaults to the Android-emulator alias
/// `http://10.0.2.2:5000` for local development. Production builds MUST
/// pass an explicit HTTPS host (release builds block cleartext HTTP):
/// `flutter build appbundle --release --dart-define=API_BASE_URL=https://<production-host>`
void main() {
  runApp(const GodownApp());
}

class GodownApp extends StatefulWidget {
  const GodownApp({super.key});

  @override
  State<GodownApp> createState() => _GodownAppState();
}

class _GodownAppState extends State<GodownApp> {
  late final AuthProvider _auth;

  @override
  void initState() {
    super.initState();
    _auth = AuthProvider();
    // Validate any stored JWT via GET /api/auth/me on startup.
    WidgetsBinding.instance.addPostFrameCallback((_) => _auth.bootstrap());
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProxyProvider<AuthProvider, GodownProvider>(
          create: (ctx) => GodownProvider(
            GodownService(ctx.read<AuthProvider>().apiClient),
            ctx.read<AuthProvider>(),
          ),
          update: (_, auth, previous) =>
              previous ?? GodownProvider(GodownService(auth.apiClient), auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, InventoryProvider>(
          create: (ctx) => InventoryProvider(
            InventoryService(ctx.read<AuthProvider>().apiClient),
            ctx.read<AuthProvider>(),
          ),
          update: (_, auth, previous) =>
              previous ?? InventoryProvider(InventoryService(auth.apiClient), auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, StaffProvider>(
          create: (ctx) => StaffProvider(
            StaffService(ctx.read<AuthProvider>().apiClient),
            ctx.read<AuthProvider>(),
          ),
          update: (_, auth, previous) =>
              previous ?? StaffProvider(StaffService(auth.apiClient), auth),
        ),
      ],
      child: Builder(
        builder: (context) {
          final auth = context.watch<AuthProvider>();
          final router = buildRouter(auth);
          return MaterialApp.router(
            title: 'Godown Management',
            theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
