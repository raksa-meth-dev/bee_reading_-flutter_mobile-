enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment fromString(String env) {
    switch (env.toLowerCase()) {
      case 'production':
      case 'prod':
        return AppEnvironment.production;
      case 'staging':
      case 'stage':
        return AppEnvironment.staging;
      case 'development':
      case 'dev':
      default:
        return AppEnvironment.development;
    }
  }
}

/// Secure compile-time environment configuration.
///
/// Values can be supplied via Flutter CLI:
/// lutter run --dart-define-from-file=.env
/// or individual --dart-define=KEY=VALUE flags.
abstract final class Environment {
  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static final AppEnvironment current = AppEnvironment.fromString(_rawEnv);

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.dev.beereading.com/v1',
  );

  static const int apiTimeoutMs = int.fromEnvironment(
    'API_TIMEOUT_MS',
    defaultValue: 15000,
  );

  static const bool enableDebugLogs = bool.fromEnvironment(
    'ENABLE_DEBUG_LOGS',
    defaultValue: true,
  );

  static bool get isProduction => current == AppEnvironment.production;
  static bool get isStaging => current == AppEnvironment.staging;
  static bool get isDevelopment => current == AppEnvironment.development;
}
