import 'package:flutter/material.dart';

import '../models/kyc.dart';
import '../screens/virtual_card/verification_screens.dart';
import '../screens/virtual_card/virtual_card_controller.dart';
import '../theme/app_colors.dart';

/// Home-screen prompt nudging an unverified user to complete KYC, in the
/// style of the "Complete verification" banners on Binance/Coinbase — a
/// non-blocking reminder, not a hard wall (the wall lives in [KycGuard] on
/// the gated features themselves).
class KycBanner extends StatelessWidget {
  const KycBanner({super.key, required this.status, required this.onVerified});

  final KycVerification? status;

  /// Called after the user returns from the verification wizard, so the
  /// caller can refresh its cached status.
  final VoidCallback onVerified;

  @override
  Widget build(BuildContext context) {
    if (status?.isApproved == true) return const SizedBox.shrink();

    final pending = status?.isPendingReview ?? false;
    final rejected = status?.isRejected ?? false;

    final title = pending
        ? 'Verification in review'
        : rejected
        ? 'Verification failed — retry'
        : 'Verify your identity';
    final subtitle = pending
        ? 'We\'ll notify you once it\'s approved'
        : rejected
        ? 'Tap to resubmit your details'
        : 'Unlock crypto trading & fiat deposits';
    final icon = pending
        ? Icons.hourglass_top_rounded
        : rejected
        ? Icons.error_outline_rounded
        : Icons.verified_user_outlined;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: pending
              ? null
              : () async {
                  final controller = VirtualCardController();
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CardVerificationHubScreen(
                        controller: controller,
                        config: const VerificationFlowConfig(
                          description:
                              'Provide the necessary information to '
                              'complete\nidentity verification and unlock '
                              'crypto trading\nand fiat deposits.',
                          completedLabel: 'Continue',
                          exitToRoot: false,
                        ),
                      ),
                    ),
                  );
                  controller.dispose();
                  onVerified();
                },
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryGradientEnd],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!pending)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
