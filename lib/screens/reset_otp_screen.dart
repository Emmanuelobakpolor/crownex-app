import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'reset_password_screen.dart';

/// Step 2 of password reset — 4-digit reset-code verification.
class ResetOtpScreen extends StatefulWidget {
  const ResetOtpScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetOtpScreen> createState() => _ResetOtpScreenState();
}

class _ResetOtpScreenState extends State<ResetOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _canVerify = false;
  bool _verifying = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitsChanged() {
    final ok = _code.length == 4;
    if (ok != _canVerify) {
      setState(() => _canVerify = ok);
    }
  }

  Future<void> _verify() async {
    if (!_canVerify || _verifying) return;
    setState(() => _verifying = true);
    try {
      await AuthService.instance.verifyResetToken(
        email: widget.email,
        token: _code,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ResetPasswordScreen(email: widget.email, token: _code),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      await AuthService.instance.forgotPassword(email: widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new reset code has been sent.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
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
              const AuthAppHeader(showProgress: false),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthTitleBlock(
                        title: 'Verify Code',
                        subtitle:
                            'Enter the 4 digit reset code sent to ${widget.email}',
                      ),
                      const SizedBox(height: 40),
                      OtpDigitBoxes(
                        controllers: _controllers,
                        focusNodes: _focusNodes,
                        onChanged: _onDigitsChanged,
                      ),
                      const SizedBox(height: 32),
                      AuthPrimaryButton(
                        label: 'Verify',
                        enabled: _canVerify,
                        loading: _verifying,
                        onPressed: _verify,
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: TextButton(
                          onPressed: _resending ? null : _resend,
                          child: Text(
                            _resending ? 'Sending...' : "Didn't get a code? Resend",
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: bottomPad),
            ],
          ),
        ),
      ),
    );
  }
}
