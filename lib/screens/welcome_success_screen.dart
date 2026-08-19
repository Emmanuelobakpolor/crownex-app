import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'home_screen.dart';

/// Final confirmation after successful signup.
class WelcomeSuccessScreen extends StatelessWidget {
  const WelcomeSuccessScreen({
    super.key,
    required this.fullName,
  });

  final String fullName;

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(fullName: fullName),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final firstName = fullName.trim().split(RegExp(r'\s+')).first;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 48, 24, 16 + bottomPad),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Text(
                  'Welcome!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$firstName, your account has been\ncreated successfully',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 48),
                const _WelcomeAvatar(),
                const Spacer(flex: 3),
                AuthPrimaryButton(
                  label: "Let's go",
                  onPressed: () => _goHome(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Friendly avatar illustration for the welcome state.
class _WelcomeAvatar extends StatelessWidget {
  const _WelcomeAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE8EEFF),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/welcome_avatar.png',
          width: 180,
          height: 180,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
