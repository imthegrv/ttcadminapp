import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureSessionStore {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'ttc_access_token';
  static const _userKey = 'ttc_user';
  static const _companyKey = 'ttc_company_id';

  Future<void> save({
    required String accessToken,
    required Map<String, dynamic> user,
    required String companyId,
  }) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: accessToken),
      _storage.write(key: _userKey, value: jsonEncode(user)),
      _storage.write(key: _companyKey, value: companyId),
    ]);
  }

  Future<Map<String, dynamic>?> read() async {
    final values = await Future.wait([
      _storage.read(key: _tokenKey),
      _storage.read(key: _userKey),
      _storage.read(key: _companyKey),
    ]);
    if ((values[0] ?? '').isEmpty) return null;
    return {
      'accessToken': values[0],
      'user': values[1] == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(values[1]!)),
      'companyId': values[2] ?? '',
    };
  }

  Future<void> clear() => _storage.deleteAll();
}
