import 'package:flutter/foundation.dart';

import '../models/kyc.dart';
import '../models/user.dart';
import 'kyc_service.dart';

/// App-wide cache of the signed-in user, so screens like the home greeting
/// and settings profile card stay in sync whenever the profile is edited
/// elsewhere (e.g. a new profile picture) without manually threading the
/// updated user through every constructor.
class UserSession extends ChangeNotifier {
  CrownexUser? user;

  /// Cached identity-verification status, so KYC gates (crypto, fiat
  /// deposit) and the home banner don't each refetch it separately.
  /// Null + [kycChecked] false means "not fetched yet"; null + true means
  /// "fetched, user has never submitted".
  KycVerification? kycStatus;
  bool kycChecked = false;

  bool get kycApproved => kycStatus?.isApproved ?? false;

  void setUser(CrownexUser user) {
    this.user = user;
    notifyListeners();
  }

  void setKycStatus(KycVerification? status) {
    kycStatus = status;
    kycChecked = true;
    notifyListeners();
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
