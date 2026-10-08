import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/kyc.dart';
import '../screens/virtual_card/verification_screens.dart';
import '../screens/virtual_card/virtual_card_controller.dart';
import '../services/kyc_service.dart';
import '../services/user_session.dart';
import '../theme/app_colors.dart';

/// Wrap a feature screen that requires identity verification (crypto
/// trading, fiat deposit) with this. Shows the real feature once KYC is
/// approved; otherwise shows a locked state with a CTA into the shared
/// verification wizard, mirroring the "complete verification to unlock"
/// pattern used by mainstream crypto wallet apps.
class KycGuard extends StatefulWidget {
  const KycGuard({
    super.key,
    required this.featureName,
    required this.featureReason,
    required this.child,
  });

  /// e.g. "Crypto trading", "Fiat deposits".
  final String featureName;

  /// Short sentence explaining why verification is required for this
  /// specific feature, shown under the headline.
  final String featureReason;

  final Widget child;

  @override
  State<KycGuard> createState() => _KycGuardState();
}

class _KycGuardState extends State<KycGuard> {
  bool _loading = true;
  KycVerification? _status;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final session = context.read<UserSession>();
    if (!session.kycChecked) {
      try {
        session.setKycStatus(await KycService.instance.getStatus());
      } catch (_) {
        // Leave kycChecked false so we retry next time rather than caching
        // a false negative from a transient network error.
      }
    }
    if (!mounted) return;
    setState(() {
      _status = session.kycStatus;
      _loading = false;
    });
  }

  Future<void> _startVerification() async {
    final controller = VirtualCardController();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CardVerificationHubScreen(
          controller: controller,
          config: const VerificationFlowConfig(
            description:
                'Provide the necessary information to complete\n'
                'identity verification and unlock this feature.',
            completedLabel: 'Continue',
            exitToRoot: false,
          ),
        ),
      ),
    );
    controller.dispose();
    if (!mounted) return;
    setState(() => _loading = true);
    await context.read<UserSession>().refreshKycStatus();
    if (!mounted) return;
    setState(() {
      _status = context.read<UserSession>().kycStatus;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_status?.isApproved == true) return widget.child;
    return _KycLockedScreen(
      featureName: widget.featureName,
      featureReason: widget.featureReason,
      status: _status,
      onVerify: _startVerification,
    );
  }
}

class _KycLockedScreen extends StatelessWidget {
  const _KycLockedScreen({
    required this.featureName,
    required this.featureReason,
    required this.status,
    required this.onVerify,
  });

  final String featureName;
  final String featureReason;
  final KycVerification? status;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final pending = status?.isPendingReview ?? false;
    final rejected = status?.isRejected ?? false;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    pending
                        ? Icons.hourglass_top_rounded
                        : rejected
                        ? Icons.error_outline_rounded
                        : Icons.verified_user_outlined,
                    color: AppColors.primary,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  pending
                      ? 'Verification in review'
                      : rejected
                      ? 'Verification needed'
                      : 'Verify your identity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  pending
                      ? 'We\'re reviewing your submission. $featureName '
                            'unlocks automatically once you\'re approved — '
                            'this usually takes just a few minutes.'
                      : featureReason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                if (!pending) _ReasonsCard(featureName: featureName),
                const Spacer(flex: 3),
                if (!pending)
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: onVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        rejected ? 'Retry verification' : 'Verify identity',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (pending)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Back to home',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonsCard extends StatelessWidget {
  const _ReasonsCard({required this.featureName});

  final String featureName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Takes about 2 minutes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const _ReasonRow(
            icon: Icons.badge_outlined,
            text: 'A valid government-issued ID',
          ),
          const SizedBox(height: 8),
          const _ReasonRow(
            icon: Icons.camera_alt_outlined,
            text: 'A quick selfie to confirm it\'s you',
          ),
          const SizedBox(height: 8),
          _ReasonRow(
            icon: Icons.lock_outline_rounded,
            text: 'Keeps $featureName secure and compliant',
          ),
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
