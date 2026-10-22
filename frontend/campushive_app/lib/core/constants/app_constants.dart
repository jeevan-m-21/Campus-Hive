abstract final class AppConstants {
  static const String _defaultApiBaseUrl = 'http://192.168.31.90:5000/api/v1';

  /// Base URL for CampusHive backend API endpoints.
  ///
  /// Can be overridden at build or run time via Flutter environment definitions:
  /// `--dart-define=API_BASE_URL=<URL>`
  ///
  /// Preserves the local developer network URL as default so existing testing continues to work.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );
}
