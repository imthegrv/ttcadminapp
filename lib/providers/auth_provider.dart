import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/secure_session_store.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider() {
    api = ApiClient(tokenProvider: () => _accessToken);
  }

  final AuthService _authService = AuthService();
  final SecureSessionStore _sessionStore = SecureSessionStore();
  late final ApiClient api;

  bool _isLoading = false;
  String? _errorMessage;
  String _accessToken = '';
  String _companyId = '';
  String? _challenge;
  Map<String, dynamic> _user = {};

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _accessToken.isNotEmpty;
  bool get requires2fa => (_challenge ?? '').isNotEmpty;
  String? get errorMessage => _errorMessage;
  String get companyId => _companyId;
  Map<String, dynamic> get user => _user;
  String get displayName {
    final first = _user['FirstName'] ?? _user['firstName'] ?? '';
    final last = _user['LastName'] ?? _user['lastName'] ?? '';
    final combined = '$first $last'.trim();
    return combined.isNotEmpty
        ? combined
        : (_user['Email'] ?? _user['email'] ?? 'Team member').toString();
  }

  Future<void> restoreSession() async {
    final saved = await _sessionStore.read();
    if (saved == null) return;
    _accessToken = saved['accessToken']?.toString() ?? '';
    _companyId = saved['companyId']?.toString() ?? '';
    _user = Map<String, dynamic>.from(saved['user'] as Map? ?? {});
    notifyListeners();
  }

  Future<bool> login(String email, String password, String companyId) async {
    _setLoading(true);
    _errorMessage = null;
    _companyId = companyId.trim();
    try {
      final result = await _authService.login(email, password, companyId);
      if (result.mustSetup2fa) {
        _errorMessage =
            'Your company requires 2FA setup. Complete setup once in the web admin, then return here.';
        return false;
      }
      if (result.requires2fa) {
        _challenge = result.challenge;
        notifyListeners();
        return false;
      }
      return _completeLogin(result);
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verify2fa(String code, {bool backupCode = false}) async {
    if (_challenge == null) return false;
    _setLoading(true);
    _errorMessage = null;
    try {
      final result = await _authService.verify2fa(
        challenge: _challenge!,
        companyId: _companyId,
        code: code.trim(),
        isBackupCode: backupCode,
      );
      return _completeLogin(result);
    } catch (error) {
      _errorMessage = _message(error);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _completeLogin(LoginResult result) async {
    final token = result.accessToken ?? '';
    if (token.isEmpty) {
      _errorMessage = 'The server did not return a valid access token.';
      return false;
    }
    _accessToken = token;
    _user = result.user;
    _challenge = null;
    await _sessionStore.save(
      accessToken: token,
      user: _user,
      companyId: _companyId,
    );
    notifyListeners();
    return true;
  }

  Future<void> logout() async {
    await _sessionStore.clear();
    _accessToken = '';
    _companyId = '';
    _challenge = null;
    _user = {};
    notifyListeners();
  }

  void cancel2fa() {
    _challenge = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Could not connect to TripClub. Check your internet connection.';
      }
    }
    return 'Sign in failed. Please verify your details and try again.';
  }
}
