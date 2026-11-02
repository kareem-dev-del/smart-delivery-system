class AppConfig {
  const AppConfig._();

  // Android emulators reach the host machine through 10.0.2.2. Override this
  // at launch for a physical device or another environment.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String loginPath = '/api/token/';
  static const String refreshPath = '/api/token/refresh/';
  static const String registerPath = '/api/accounts/register/';
  static const String currentUserPath = '/api/accounts/me/';
  static const String courierAssignmentsPath =
      '/api/orders/courier/assignments/';
  static const String courierReturnsPath = '/api/orders/courier/returns/';
  static const String courierShiftPath = '/api/accounts/couriers/me/shift/';

  /// Search still uses this flag to choose between API and local data.
  static const bool useApi = true;
}
