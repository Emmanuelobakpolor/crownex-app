import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/kyc_guard.dart';
import 'deposit_ngn_screen.dart';
import 'withdraw_ngn_screen.dart';

/// Menu: Deposit NGN / Withdraw NGN.
class TopUpWithdrawMenuScreen extends StatelessWidget {
  const TopUpWithdrawMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    AuthBackButton(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Top-up/ Withdrawal',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _MenuTile(
                      label: 'Deposit NGN',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                            builder: (_) => const KycGuard(
                              featureName: 'Fiat deposits',
                              featureReason:
                                  'To keep your funds safe and comply with '
                                  'regulations, we need to verify your '
                                  'identity before you can deposit money.',
                              child: DepositNgnScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _MenuTile(
                      label: 'Withdraw NGN',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const WithdrawNgnScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB8C9F5), width: 1.2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
