import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import 'sign_in_screen.dart';
import 'sign_up_screen.dart';

class OnboardingPageData {
  const OnboardingPageData({
    required this.imageAsset,
    required this.title,
    required this.subtitle,
    this.imageHeightFactor = 0.42,
  });

  final String imageAsset;
  final String title;
  final String subtitle;
  final double imageHeightFactor;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<OnboardingPageData> _pages = [
    OnboardingPageData(
      imageAsset: 'assets/images/onboarding_coins.png',
      title: 'Transact Crypto\nExchange',
      subtitle:
          'Effortlessly purchase, deposit and swap\ncrypto all from one secure app',
      imageHeightFactor: 0.44,
    ),
    OnboardingPageData(
      imageAsset: 'assets/images/onboarding_payments.png',
      title: 'Purchase Airtime,\nData, Electricity',
      subtitle:
          'Quickly pay for electricity, data, airtime, and\nmore, right from your phone',
      imageHeightFactor: 0.42,
    ),
    OnboardingPageData(
      imageAsset: 'assets/images/Screenshot 2026-07-13 213928.png',
      title: 'Purchase iTunes at a &\ngo with ease',
      subtitle:
          'Convert crypto to cash and settle bills\ninstantly with bank-grade security',
      imageHeightFactor: 0.45,
    ),
  ];

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  void _goToSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
    );
  }

  void _goToSignIn() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _OnboardingPage(
                      data: page,
                      imageHeight: size.height * page.imageHeightFactor,
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottomPad),
                child: Column(
                  children: [
                    _PageIndicator(
                      count: _pages.length,
                      current: _currentPage,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _goToSignUp,
                        child: const Text('Get Started'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: _goToSignIn,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w400,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign in',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.imageHeight,
  });

  final OnboardingPageData data;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),
          SizedBox(
            height: imageHeight,
            width: double.infinity,
            child: Image.asset(
              data.imageAsset,
              fit: BoxFit.contain,
            ),
          ),
          const Spacer(flex: 2),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 14),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 15.5,
                ),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.current,
  });

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 8 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.dotInactive,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
