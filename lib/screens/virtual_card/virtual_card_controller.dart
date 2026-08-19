import 'package:flutter/foundation.dart';

import '../../models/card.dart';
import '../../models/kyc.dart';
import '../../services/card_service.dart';
import '../../services/kyc_service.dart';

enum VirtualCardPhase {
  /// No request yet — show marketing / request CTA.
  intro,

  /// User submitted verification; waiting / approved to create.
  pending,

  /// All steps confirmed — ready to create card.
  approved,

  /// Card exists — dashboard.
  active,
}

/// Shared state for the virtual card tab & creation flow.
class VirtualCardController extends ChangeNotifier {
  bool personalDone = false;
  bool identityDone = false;
  bool addressDone = false;
  bool reviewSeen = false;

  /// True once a KYC submission was rejected — surfaced so the UI can
  /// prompt the user to retry instead of showing "review pending" forever.
  bool kycRejected = false;

  /// The real Bitnob-backed card, once requested — null until then.
  VirtualCard? card;
  String? cardHolder;

  /// Carries the selfie picked in PersonalInfoScreen through to the actual
  /// KycService.submitVerification call made from IdentityVerificationScreen.
  String? selfiePath;
  String? addressText;

  bool get cardCreated => card != null;

  VirtualCardPhase get phase {
    if (cardCreated) return VirtualCardPhase.active;
    if (personalDone && identityDone && addressDone && reviewSeen) {
      return VirtualCardPhase.approved;
    }
    if (personalDone || identityDone || addressDone) {
      return VirtualCardPhase.pending;
    }
    return VirtualCardPhase.intro;
  }

  bool get allVerificationDone =>
      personalDone && identityDone && addressDone;

  void completePersonal({String? name, String? selfiePath}) {
    personalDone = true;
    if (name != null && name.isNotEmpty) cardHolder = name;
    if (selfiePath != null) this.selfiePath = selfiePath;
    notifyListeners();
  }

  void completeIdentity() {
    identityDone = true;
    notifyListeners();
  }

  void completeAddress({String? address}) {
    addressDone = true;
    if (address != null) addressText = address;
    notifyListeners();
  }

  void markReviewSeen() {
    reviewSeen = true;
    notifyListeners();
  }

  /// Pulls the real verification status from the backend and updates local
  /// flags accordingly — called on entering the verification hub and the
  /// review-pending screen, replacing the old client-only auto-approve.
  Future<void> syncFromBackend() async {
    KycVerification? verification;
    try {
      verification = await KycService.instance.getStatus();
    } catch (_) {
      return;
    }
    if (verification == null) return;

    if (verification.isApproved) {
      personalDone = true;
      identityDone = true;
      addressDone = true;
      reviewSeen = true;
      kycRejected = false;
    } else if (verification.isRejected) {
      kycRejected = true;
    } else {
      kycRejected = false;
    }
    notifyListeners();
  }

  /// POST /api/cards/request/ — KYC- and PIN-gated. Throws ApiException on
  /// failure (insufficient KYC, wrong PIN, Bitnob error) for the caller to
  /// surface; on success the card is created pending, poll
  /// [syncCardFromBackend] for the final provisioned state.
  Future<void> requestCard({required String pin}) async {
    card = await CardService.instance.requestCard(pin: pin, address: addressText ?? '');
    notifyListeners();
  }

  /// Pulls the real card status from the backend — called by
  /// CardPreparingScreen while polling, and whenever the dashboard needs a
  /// fresh balance/status after fund/withdraw/freeze actions.
  Future<VirtualCard?> syncCardFromBackend() async {
    try {
      card = await CardService.instance.getStatus();
    } catch (_) {
      return card;
    }
    notifyListeners();
    return card;
  }

  void reset() {
    personalDone = false;
    identityDone = false;
    addressDone = false;
    reviewSeen = false;
    kycRejected = false;
    card = null;
    cardHolder = null;
    selfiePath = null;
    addressText = null;
    notifyListeners();
  }
}
