/// Central API configuration.
///
/// Development default is the Android-emulator loopback alias
/// `10.0.2.2` (plain HTTP is fine on the emulator; Android blocks
/// cleartext HTTP in release builds, so production MUST use HTTPS).
///
/// PRODUCTION: always build with an explicit HTTPS host, never rely on
/// the default below:
///   `flutter build appbundle --release --dart-define=API_BASE_URL=https://<production-host>`
/// (No production URL is hardcoded here on purpose.)
///
/// Local overrides without code changes:
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
