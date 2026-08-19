import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/user_session.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'welcome_success_screen.dart';

/// Set (and optionally confirm) a 4-digit transaction PIN.
class SetTransactionPinScreen extends StatefulWidget {
  const SetTransactionPinScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.phone,
    this.existingPin,
  });

  final String fullName;
  final String email;
  final String phone;

  /// When non-null, this screen is the confirm-PIN step.
  final String? existingPin;

  bool get isConfirm => existingPin != null;

  @override
  State<SetTransactionPinScreen> createState() =>
      _SetTransactionPinScreenState();
}

class _SetTransactionPinScreenState extends State<SetTransactionPinScreen> {
  String _pin = '';
  String? _error;
  bool _submitting = false;

  void _onDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _confirm() async {
    if (_pin.length != 4 || _submitting) return;

    if (!widget.isConfirm) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SetTransactionPinScreen(
            fullName: widget.fullName,
            email: widget.email,
            phone: widget.phone,
            existingPin: _pin,
          ),
        ),
      );
      return;
    }

    if (_pin != widget.existingPin) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _pin = '';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final user = await AuthService.instance.setTransactionPin(
        pin: widget.existingPin!,
        pinConfirm: _pin,
      );
      if (!mounted) return;
      context.read<UserSession>().setUser(user);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => WelcomeSuccessScreen(fullName: widget.fullName),
        ),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _pin = '';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final canConfirm = _pin.length == 4;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AuthAppHeader(
                showProgress: false,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthTitleBlock(
                        title: widget.isConfirm
                            ? 'Confirm Transaction Pin'
                            : 'Set Transaction Pin',
                        subtitle: widget.isConfirm
                            ? 'Enter the four digits number again to confirm the transaction pin'
                            : 'Enter a four digits number that you use to make transactions',
                      ),
                      const SizedBox(height: 40),
                      PinDotBoxes(length: 4, filledCount: _pin.length),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const Spacer(),
                      AuthPrimaryButton(
                        label: 'Confirm',
                        enabled: canConfirm,
                        loading: _submitting,
                        onPressed: _confirm,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              // Soft system-style numeric keypad area (design shows OS keyboard;
              // we provide an in-app pad so PIN works on all platforms).
              NumericKeypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                bottomInset: bottomPad,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
