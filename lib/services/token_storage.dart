import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT access/refresh token pair issued by the backend.
class TokenStorage {
  TokenStorage._();

  static final TokenStorage instance = TokenStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _accessKey = 'crownex_access_token';
  static const _refreshKey = 'crownex_refresh_token';

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _accessKey, value: access);
    await _storage.write(key: _refreshKey, value: refresh);
  }

  Future<void> saveAccessToken(String access) {
    return _storage.write(key: _accessKey, value: access);
  }

  Future<String?> get accessToken => _storage.read(key: _accessKey);

  Future<String?> get refreshToken => _storage.read(key: _refreshKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
