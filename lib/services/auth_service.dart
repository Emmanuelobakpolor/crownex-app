import '../models/user.dart';
import 'api_client.dart';
import 'token_storage.dart';

/// Typed wrapper over the /api/auth/* and /api/profile/ endpoints
/// (crownex-backend/accounts/urls.py). Persists the JWT pair on
/// successful login / profile completion, and clears it on logout.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final ApiClient _client = ApiClient.instance;

  /// Step 1 — POST /auth/register/
  Future<void> register({required String email, required String phone}) async {
    await _client.post('/auth/register/', body: {'email': email, 'phone': phone});
  }

  /// Step 2 — POST /auth/verify-otp/
  Future<void> verifyOtp({required String email, required String otp}) async {
    await _client.post('/auth/verify-otp/', body: {'email': email, 'otp': otp});
  }

  /// Resend the registration OTP — POST /auth/resend-otp/
  Future<void> resendOtp({required String email}) async {
    await _client.post('/auth/resend-otp/', body: {'email': email});
  }

  /// Step 3 — POST /auth/complete-profile/. Issues and stores the JWT pair.
  Future<CrownexUser> completeProfile({
    required String email,
    required String fullName,
    required String password,
    required String passwordConfirm,
  }) async {
    final data = await _client.post(
      '/auth/complete-profile/',
      body: {
        'email': email,
        'full_name': fullName,
        'password': password,
        'password_confirm': passwordConfirm,
      },
    );
    return _saveSession(data);
  }

  /// Step 4 — POST /auth/set-transaction-pin/ (requires the token from step 3).
  Future<CrownexUser> setTransactionPin({
    required String pin,
    required String pinConfirm,
  }) async {
    final data = await _client.post(
      '/auth/set-transaction-pin/',
      body: {'pin': pin, 'pin_confirm': pinConfirm},
      auth: true,
    );
    return CrownexUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// POST /auth/login/. Issues and stores the JWT pair.
  Future<CrownexUser> login({required String email, required String password}) async {
    final data = await _client.post(
      '/auth/login/',
      body: {'email': email, 'password': password},
    );
    return _saveSession(data);
  }

  /// POST /auth/logout/ (blacklists the refresh token), then clears local storage.
  /// Local session is always cleared, even if the network call fails.
  Future<void> logout() async {
    final refresh = await TokenStorage.instance.refreshToken;
    try {
      if (refresh != null) {
        await _client.post('/auth/logout/', body: {'refresh': refresh}, auth: true);
      }
    } catch (_) {
      // Best-effort server-side blacklist; local logout must still proceed.
    } finally {
      await TokenStorage.instance.clear();
    }
  }

  /// POST /auth/forgot-password/
  Future<void> forgotPassword({required String email}) async {
    await _client.post('/auth/forgot-password/', body: {'email': email});
  }

  /// POST /auth/verify-reset-token/
  Future<void> verifyResetToken({required String email, required String token}) async {
    await _client.post(
      '/auth/verify-reset-token/',
      body: {'email': email, 'token': token},
    );
  }

  /// POST /auth/reset-password/
  Future<void> resetPassword({
    required String email,
    required String token,
    required String password,
    required String passwordConfirm,
  }) async {
    await _client.post(
      '/auth/reset-password/',
      body: {
        'email': email,
        'token': token,
        'password': password,
        'password_confirm': passwordConfirm,
      },
    );
  }

  /// GET /api/profile/ — used on app start to validate a stored session.
  Future<CrownexUser> fetchProfile() async {
    final data = await _client.get('/profile/', auth: true);
    return CrownexUser.fromJson(data);
  }

  /// PATCH /api/profile/ — updates name/phone and, when [imagePath] is
  /// given, uploads a new profile picture as multipart form data.
  Future<CrownexUser> updateProfile({
    String? fullName,
    String? phone,
    String? imagePath,
  }) async {
    final fields = <String, String>{};
    if (fullName != null) fields['full_name'] = fullName;
    if (phone != null) fields['phone'] = phone;

    final data = imagePath != null
        ? await _client.patchMultipart(
            '/profile/',
            fields: fields,
            fileField: 'profile_picture',
            filePath: imagePath,
            auth: true,
          )
        : await _client.patch('/profile/', body: fields, auth: true);

    return CrownexUser.fromJson(data);
  }

  /// POST /auth/change-password/ (requires the current password).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    await _client.post(
      '/auth/change-password/',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirm': newPasswordConfirm,
      },
      auth: true,
    );
  }

  /// POST /auth/change-transaction-pin/ (requires the current PIN).
  Future<CrownexUser> changeTransactionPin({
    required String currentPin,
    required String newPin,
    required String newPinConfirm,
  }) async {
    final data = await _client.post(
      '/auth/change-transaction-pin/',
      body: {
        'current_pin': currentPin,
        'new_pin': newPin,
        'new_pin_confirm': newPinConfirm,
      },
      auth: true,
    );
    return CrownexUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<bool> hasStoredSession() async {
    return (await TokenStorage.instance.accessToken) != null;
  }

  /// Drops the local session without calling the backend — used when a
  /// stored token turns out to be invalid/expired on app start.
  Future<void> clearLocalSession() => TokenStorage.instance.clear();

  Future<CrownexUser> _saveSession(Map<String, dynamic> data) async {
    final access = data['access'] as String;
    final refresh = data['refresh'] as String;
    await TokenStorage.instance.saveTokens(access: access, refresh: refresh);
    return CrownexUser.fromJson(data['user'] as Map<String, dynamic>);
  }
}
