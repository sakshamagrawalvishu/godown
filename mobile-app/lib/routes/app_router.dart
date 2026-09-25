import 'package:go_router/go_router.dart';
import '../models/inventory_item.dart';
import '../providers/auth_provider.dart';
import '../screens/dashboard_screen.dart';
import '../screens/godown_detail_screen.dart';
import '../screens/godown_form_screen.dart';
import '../screens/godown_list_screen.dart';
import '../screens/inventory_form_screen.dart';
import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/staff_create_screen.dart';
import '../screens/staff_list_screen.dart';

/// App navigation (go_router), driven by [AuthProvider] status.
///
/// Splash/Auth check -> Login -> Dashboard -> My Godowns
/// -> Create/Edit Godown -> Godown Details -> Add/Edit Inventory.
///
/// Login is the normal entry point: public Owner self-registration was
/// removed to match the backend lockdown (POST /api/auth/register rejects
/// role OWNER). Owners are seeded server-side; staff are created by owners.
GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/splash',
    redirect: (context, state) {
      final checking = auth.status == AuthStatus.checking;
      final loggedIn = auth.status == AuthStatus.authenticated;
      final loc = state.matchedLocation;

      if (checking) return loc == '/splash' ? null : '/splash';
      if (!loggedIn) {
        return loc == '/login' ? null : '/login';
      }
      // Staff management is Owner-only in the UI (backend also enforces
      // 403 for STAFF tokens). Bounce STAFF deep-links back to dashboard.
      if ((loc == '/staff' || loc.startsWith('/staff/')) && !auth.isOwner) {
        return '/dashboard';
      }
      if (loc == '/splash' || loc == '/login' || loc == '/') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
      GoRoute(path: '/staff', builder: (c, s) => const StaffListScreen()),
      GoRoute(path: '/staff/new', builder: (c, s) => const StaffCreateScreen()),
      GoRoute(path: '/godowns', builder: (c, s) => const GodownListScreen()),
      GoRoute(path: '/godowns/new', builder: (c, s) => const GodownFormScreen()),
      GoRoute(
        path: '/godowns/:id',
        builder: (c, s) => GodownDetailScreen(godownId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/godowns/:id/edit',
        builder: (c, s) => GodownFormScreen(godownId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/godowns/:gid/inventory/new',
        builder: (c, s) => InventoryFormScreen(godownId: s.pathParameters['gid']!),
      ),
      GoRoute(
        path: '/godowns/:gid/inventory/:iid/edit',
        builder: (c, s) => InventoryFormScreen(
          godownId: s.pathParameters['gid']!,
          existing: s.extra is InventoryItem ? s.extra as InventoryItem : null,
        ),
      ),
    ],
  );
}
