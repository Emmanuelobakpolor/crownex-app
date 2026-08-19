import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import 'session_guard.dart';
import 'token_storage.dart';

/// Thin JSON HTTP wrapper around the Crownex Django backend.
///
/// Handles base-URL resolution, bearer-token attachment, one-shot access
/// token refresh on a 401, and normalizing the backend's error shapes
/// (`{detail, code}` domain errors vs. DRF's `{field: [messages]}`
/// validation errors) into a single [ApiException].
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();

  Future<Map<String, dynamic>> get(String path, {bool auth = false}) {
    return _request('GET', path, auth: auth);
  }

  /// GET for endpoints that return a bare JSON array instead of an object.
  Future<List<dynamic>> getList(String path, {bool auth = false}) {
    return _requestList('GET', path, auth: auth);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) {
    return _request('POST', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) {
    return _request('PATCH', path, body: body, auth: auth);
  }

  /// Multipart PATCH — used for the profile endpoint when a new profile
  /// picture file is included alongside (optional) text fields.
  Future<Map<String, dynamic>> patchMultipart(
    String path, {
    Map<String, String>? fields,
    String? fileField,
    String? filePath,
    bool auth = false,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final request = http.MultipartRequest('PATCH', uri);

    if (auth) {
      final token = await TokenStorage.instance.accessToken;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    }
    if (fields != null) request.fields.addAll(fields);
    if (filePath != null && fileField != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }

    http.Response response;
    try {
      final streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (response.statusCode == 401 && auth && _isJwtAuthError(response.body)) {
      if (!isRetry) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return patchMultipart(
            path,
            fields: fields,
            fileField: fileField,
            filePath: filePath,
            auth: auth,
            isRetry: true,
          );
        }
      }
      throw await _sessionExpired();
    }

    final decoded = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw _errorFrom(decoded, response.statusCode);
  }

  /// Multipart POST — used for the crypto payment-proof upload, and any
  /// upload needing more than one file (e.g. KYC selfie + ID document) via
  /// [extraFiles] (field name -> file path).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    Map<String, String>? fields,
    String? fileField,
    String? filePath,
    Map<String, String>? extraFiles,
    bool auth = false,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final request = http.MultipartRequest('POST', uri);

    if (auth) {
      final token = await TokenStorage.instance.accessToken;
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
    }
    if (fields != null) request.fields.addAll(fields);
    if (filePath != null && fileField != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }
    if (extraFiles != null) {
      for (final entry in extraFiles.entries) {
        request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
      }
    }

    http.Response response;
    try {
      final streamed = await request.send();
      response = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (response.statusCode == 401 && auth && _isJwtAuthError(response.body)) {
      if (!isRetry) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return postMultipart(
            path,
            fields: fields,
            fileField: fileField,
            filePath: filePath,
            extraFiles: extraFiles,
            auth: auth,
            isRetry: true,
          );
        }
      }
      throw await _sessionExpired();
    }

    final decoded = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw _errorFrom(decoded, response.statusCode);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (auth) {
      final token = await TokenStorage.instance.accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final encodedBody = body != null ? jsonEncode(body) : null;

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _http.get(uri, headers: headers);
        case 'POST':
          response = await _http.post(uri, headers: headers, body: encodedBody);
        case 'PATCH':
          response = await _http.patch(uri, headers: headers, body: encodedBody);
        default:
          throw ApiException('Unsupported request method: $method');
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (response.statusCode == 401 && auth && _isJwtAuthError(response.body)) {
      if (!isRetry) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return _request(method, path, body: body, auth: auth, isRetry: true);
        }
      }
      throw await _sessionExpired();
    }

    final decoded = _decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw _errorFrom(decoded, response.statusCode);
  }

  Future<List<dynamic>> _requestList(
    String method,
    String path, {
    bool auth = false,
    bool isRetry = false,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (auth) {
      final token = await TokenStorage.instance.accessToken;
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    try {
      response = await _http.get(uri, headers: headers);
    } catch (_) {
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (response.statusCode == 401 && auth && _isJwtAuthError(response.body)) {
      if (!isRetry) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return _requestList(method, path, auth: auth, isRetry: true);
        }
      }
      throw await _sessionExpired();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return const [];
      final decoded = jsonDecode(response.body);
      return decoded is List ? decoded : const [];
    }

    throw _errorFrom(_decode(response.body), response.statusCode);
  }

  /// The access token is invalid/expired and refreshing it failed (or there
  /// was never a refresh token to begin with — e.g. credentials not sent).
  /// Kicks off the app-wide "back to sign-in" redirect and hands back an
  /// exception flagged so screens can ignore it instead of surfacing raw
  /// backend text like "Given token not valid for any token type".
  Future<ApiException> _sessionExpired() async {
    unawaited(SessionGuard.instance.forceLogout());
    return ApiException(
      'Your session has expired. Please log in again.',
      code: 'session_expired',
      statusCode: 401,
    );
  }

  Future<bool> _tryRefresh() async {
    final refresh = await TokenStorage.instance.refreshToken;
    if (refresh == null) return false;

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/refresh/');
      final response = await _http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      );

      if (response.statusCode != 200) {
        await TokenStorage.instance.clear();
        return false;
      }

      final decoded = _decode(response.body);
      final newAccess = decoded['access'] as String?;
      if (newAccess == null) return false;

      final newRefresh = decoded['refresh'] as String?;
      if (newRefresh != null) {
        await TokenStorage.instance.saveTokens(access: newAccess, refresh: newRefresh);
      } else {
        await TokenStorage.instance.saveAccessToken(newAccess);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  /// Codes SimpleJWT itself attaches to an invalid/expired-token 401
  /// (`rest_framework_simplejwt.exceptions.InvalidToken`/`NotAuthenticated`).
  /// Any other `code` on a 401 (e.g. `invalid_pin`, `pin_not_set` from our
  /// own domain services) means the token was fine and the backend is
  /// reporting a real domain error that happens to use status 401 — that
  /// must NOT trigger a token refresh + force logout.
  static const _jwtErrorCodes = {
    'token_not_valid',
    'user_not_found',
    'authentication_failed',
    'not_authenticated',
  };

  bool _isJwtAuthError(String body) {
    if (body.isEmpty) return true; // no body at all — assume a real auth failure
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final code = decoded['code'] as String?;
        if (code != null) return _jwtErrorCodes.contains(code);
      }
    } catch (_) {
      // Non-JSON body on a 401 — treat as a genuine auth failure.
    }
    return true;
  }

  ApiException _errorFrom(Map<String, dynamic> decoded, int statusCode) {
    if (decoded['detail'] is String) {
      return ApiException(
        decoded['detail'] as String,
        code: decoded['code'] as String?,
        statusCode: statusCode,
      );
    }

    // DRF validation-error shape: {"email": ["Enter a valid email address."]}
    final fieldErrors = <String, List<String>>{};
    String? firstMessage;
    decoded.forEach((key, value) {
      if (value is List) {
        final messages = value.map((e) => e.toString()).toList();
        fieldErrors[key] = messages;
        firstMessage ??= messages.isNotEmpty ? messages.first : null;
      }
    });

    if (firstMessage != null) {
      return ApiException(firstMessage!, statusCode: statusCode, fieldErrors: fieldErrors);
    }

    return ApiException('Something went wrong. Please try again.', statusCode: statusCode);
  }
}
