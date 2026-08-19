import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/user_session.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    final hasSession = await AuthService.instance.hasStoredSession();
    CrownexUser? user;
    var sessionExpired = false;
    if (hasSession) {
      try {
        user = await AuthService.instance.fetchProfile();
      } on ApiException catch (e) {
        // Stored token is invalid/expired and couldn't be refreshed. If it
        // was a 401, SessionGuard is already redirecting to sign-in — don't
        // also race it with our own navigation below.
        sessionExpired = e.isSessionExpired;
        await AuthService.instance.clearLocalSession();
      } catch (_) {
        await AuthService.instance.clearLocalSession();
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (!mounted || sessionExpired) return;

    if (user != null) {
      context.read<UserSession>().setUser(user);
    }

    final resolvedUser = user;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => resolvedUser != null
            ? HomeScreen(fullName: resolvedUser.fullName)
            : const OnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 450),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Image.asset(
                'assets/images/app_logo-removebg-preview.png',
                width: 108,
                height: 108,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
