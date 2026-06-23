import 'package:dio/dio.dart';
import '../config/app_config.dart';

class LoginResult {
  const LoginResult({
    this.accessToken,
    this.user = const {},
    this.challenge,
    this.mustSetup2fa = false,
  });

  final String? accessToken;
  final Map<String, dynamic> user;
  final String? challenge;
  final bool mustSetup2fa;

  bool get requires2fa => challenge != null && challenge!.isNotEmpty;
}

class AuthService {
  AuthService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );

  final Dio _dio;

  Future<LoginResult> login(
    String email,
    String password,
    String companyId,
  ) async {
    final response = await _dio.post(
      '/auth/company/login',
      data: {
        'Email': email.trim(),
        'Password': password,
        'MasterCompanyId': companyId.trim(),
        'UserType': 'Employee',
      },
    );
    return _parse(response.data);
  }

  Future<LoginResult> verify2fa({
    required String challenge,
    required String companyId,
    required String code,
    required bool isBackupCode,
  }) async {
    final response = await _dio.post(
      '/auth/company/login/2fa',
      data: {
        'challenge': challenge,
        'MasterCompanyId': companyId,
        'UserType': 'Employee',
        if (isBackupCode) 'backupCode': code else 'token': code,
      },
    );
    return _parse(response.data);
  }

  LoginResult _parse(dynamic raw) {
    final data = Map<String, dynamic>.from(raw as Map);
    return LoginResult(
      accessToken: data['accessToken']?.toString(),
      user: data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : const {},
      challenge: data['twoFactorRequired'] == true
          ? data['challenge']?.toString()
          : null,
      mustSetup2fa:
          data['mustSetup2FA'] == true || data['mustSetupTwoFactor'] == true,
    );
  }
}
