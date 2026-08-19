import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'sign_in_screen.dart';
import 'verify_otp_screen.dart';

/// Step 1 of signup — email + phone number.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _canContinue = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_revalidate);
    _phoneController.addListener(_revalidate);
  }

  void _revalidate() {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final ok = email.contains('@') && email.contains('.') && phone.length >= 10;
    if (ok != _canContinue) {
      setState(() => _canContinue = ok);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    setState(() => _loading = true);
    try {
      await AuthService.instance.register(email: email, phone: phone);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VerifyOtpScreen(email: email, phone: phone),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const AuthAppHeader(currentStep: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AuthTitleBlock(
                          title: 'Create Account',
                          subtitle: 'Welcome. Please enter your details',
                        ),
                        const SizedBox(height: 36),
                        const AuthFieldLabel('Email Address'),
                        AuthTextField(
                          controller: _emailController,
                          hintText: 'example@email.com',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your email address';
                            }
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        const AuthFieldLabel('Phone Number'),
                        AuthTextField(
                          controller: _phoneController,
                          hintText: '08000000000',
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          onChanged: (_) {},
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your phone number';
                            }
                            if (value.trim().length < 10) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 12 + bottomPad),
                child: Column(
                  children: [
                    AuthPrimaryButton(
                      label: 'Continue',
                      enabled: _canContinue,
                      loading: _loading,
                      onPressed: _continue,
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const SignInScreen(),
                          ),
                        );
                      },
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
                            children: const [
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
