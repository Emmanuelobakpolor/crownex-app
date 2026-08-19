import 'package:flutter/material.dart';

import '../screens/sign_in_screen.dart';
import 'token_storage.dart';
import 'user_session.dart';

/// Detects an expired/invalid session (refresh failed, or the backend
/// rejected the access token outright) and reacts the same way everywhere:
/// clear local tokens, drop the cached user, and drop the user back on the
/// sign-in screen with a friendly one-line explanation — never a raw
/// "token not valid" / "credentials not provided" error on screen.
class SessionGuard {
  SessionGuard._();

  static final SessionGuard instance = SessionGuard._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  UserSession? _userSession;
  bool _handling = false;

  /// Wired once from the widget tree (e.g. in [CrownexApp]) so this can
  /// clear the cached user alongside the stored tokens.
  void attach(UserSession session) {
    _userSession = session;
  }

  /// Call the instant a 401 survives a token refresh attempt. Safe to call
  /// from multiple in-flight requests at once — only the first call acts.
  Future<void> forceLogout({
    String message = 'Your session has expired. Please log in again.',
  }) async {
    if (_handling) return;
    _handling = true;
    try {
      await TokenStorage.instance.clear();
      _userSession?.clear();

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => SignInScreen(successMessage: message),
        ),
        (_) => false,
      );
    } finally {
      _handling = false;
    }
  }
}
