import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'onboarding_screen.dart';

/// Temporary home after auth — full product screens come next.
class HomePlaceholderScreen extends StatelessWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 72,
                  height: 72,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Welcome to Crownex',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'Crypto. Pay bills. Live easy.\nYour dashboard is ready for the next build.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/card_preview.png',
                  fit: BoxFit.cover,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const OnboardingScreen(),
                    ),
                    (_) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  foregroundColor: AppColors.textPrimary,
                ),
                child: const Text('Back to onboarding'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
