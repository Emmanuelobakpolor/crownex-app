import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/kyc.dart';
import '../models/user.dart';
import '../theme/app_colors.dart';
import 'kyc_service.dart';

/// App-wide cache of the signed-in user, so screens like the home greeting
/// and settings profile card stay in sync whenever the profile is edited
/// elsewhere (e.g. a new profile picture) without manually threading the
/// updated user through every constructor.
class UserSession extends ChangeNotifier {
  UserSession({bool darkMode = false}) : _darkMode = darkMode {
    AppColors.setDark(darkMode);
  }

  static const String _themePreferenceKey = 'theme_mode';

  /// Reads the saved appearance before the first frame, so a dark-mode
  /// user doesn't see the app flash light on launch.
  static Future<bool> loadDarkModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_themePreferenceKey) == 'dark';
    } catch (_) {
      return false;
    }
  }

  CrownexUser? user;

  /// Cached identity-verification status, so KYC gates (crypto, fiat
  /// deposit) and the home banner don't each refetch it separately.
  /// Null + [kycChecked] false means "not fetched yet"; null + true means
  /// "fetched, user has never submitted".
  KycVerification? kycStatus;
  bool kycChecked = false;
  bool _darkMode;

  bool get kycApproved => kycStatus?.isApproved ?? false;
  bool get isDarkMode => _darkMode;
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;

  void setUser(CrownexUser user) {
    this.user = user;
    notifyListeners();
  }

  void setKycStatus(KycVerification? status) {
    kycStatus = status;
    kycChecked = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (value == _darkMode) return;
    _darkMode = value;
    AppColors.setDark(value);
    notifyListeners();
    _rebuildAllWidgets();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePreferenceKey, value ? 'dark' : 'light');
    } catch (_) {
      // The switch still works for this session; it just won't be remembered.
    }
  }

  /// Most screens read [AppColors] directly instead of through
  /// `Theme.of(context)`, so a theme change alone wouldn't repaint them.
  /// Marking every element dirty makes them rebuild with the new palette
  /// without resetting the navigation stack.
  static void _rebuildAllWidgets() {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  }

  /// Re-fetches from the backend (e.g. after the user finishes the
  /// verification wizard) rather than trusting the cache.
  Future<void> refreshKycStatus() async {
    try {
      setKycStatus(await KycService.instance.getStatus());
    } catch (_) {
      // Keep the previous cached value on transient failure.
    }
  }

  void clear() {
    user = null;
    kycStatus = null;
    kycChecked = false;
    notifyListeners();
  }
}
