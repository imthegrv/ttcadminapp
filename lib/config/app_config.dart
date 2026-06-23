class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'TTC_API_URL',
    defaultValue: 'https://v1api.thetripclub.com/v2',
  );

  /// Socket.IO server lives at the host root (the API server it is attached
  /// to), not under the `/v2` REST prefix.
  static String get socketUrl => Uri.parse(apiBaseUrl).origin;
}
