/// Central API configuration.
///
/// The backend runs on port 5000 in development.
/// `localhost` does not reach the host from an Android emulator, so the
/// default targets the emulator loopback alias `10.0.2.2`.
///
/// Override for a physical device / custom host without code changes:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  static const Duration timeout = Duration(seconds: 15);

  // Auth — public register/login, protected /me.
  // (backend: src/routes/auth.routes.js)
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String me = '/api/auth/me';

  // Godowns — writes OWNER only, reads OWNER/STAFF, owner-scoped.
  // (backend: src/routes/godown.routes.js)
  static const String godowns = '/api/godowns';
  static String godownById(String id) => '/api/godowns/$id';

  // Inventory — writes OWNER only, reads OWNER/STAFF, scoped via godown.
  // (backend: src/routes/inventory.routes.js)
  static const String inventory = '/api/inventory';
  static String inventoryById(String id) => '/api/inventory/$id';

  // Staff management — OWNER only (backend enforces authorization).
  // (backend: src/routes/user.routes.js + user.controller.js)
  // POST /api/users {name,email,password} -> {user}
  // GET /api/users?role=STAFF -> {users}
  static const String users = '/api/users';
}
