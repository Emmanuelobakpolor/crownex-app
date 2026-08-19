import 'package:flutter/foundation.dart';

import '../models/user.dart';

/// App-wide cache of the signed-in user, so screens like the home greeting
/// and settings profile card stay in sync whenever the profile is edited
/// elsewhere (e.g. a new profile picture) without manually threading the
/// updated user through every constructor.
class UserSession extends ChangeNotifier {
  CrownexUser? user;

  void setUser(CrownexUser user) {
    this.user = user;
    notifyListeners();
  }

  void clear() {
    user = null;
    notifyListeners();
  }
}
