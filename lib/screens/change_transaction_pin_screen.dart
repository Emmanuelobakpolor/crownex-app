import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/user_session.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';

enum _PinStep { current, newPin, confirmPin }

/// Three-step PIN change — current PIN, new PIN, confirm new PIN —
/// POST /api/auth/change-transaction-pin/ (verified against the stored PIN
/// server-side).
class ChangeTransactionPinScreen extends StatefulWidget {
  const ChangeTransactionPinScreen({super.key});

  @override
  State<ChangeTransactionPinScreen> createState() =>
      _ChangeTransactionPinScreenState();
}

class _ChangeTransactionPinScreenState
    extends State<ChangeTransactionPinScreen> {
  _PinStep _step = _PinStep.current;
  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  String? _error;
  bool _submitting = false;

  String get _activeValue {
    switch (_step) {
      case _PinStep.current:
        return _currentPin;
      case _PinStep.newPin:
        return _newPin;
      case _PinStep.confirmPin:
        return _confirmPin;
    }
  }

  void _onDigit(String digit) {
    if (_activeValue.length >= 4) return;
    setState(() {
      _error = null;
      switch (_step) {
        case _PinStep.current:
          _currentPin += digit;
        case _PinStep.newPin:
          _newPin += digit;
        case _PinStep.confirmPin:
          _confirmPin += digit;
      }
    });
  }

  void _onBackspace() {
    if (_activeValue.isEmpty) return;
    setState(() {
      _error = null;
      switch (_step) {
        case _PinStep.current:
          _currentPin = _currentPin.substring(0, _currentPin.length - 1);
        case _PinStep.newPin:
          _newPin = _newPin.substring(0, _newPin.length - 1);
        case _PinStep.confirmPin:
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  void _restart(String message) {
    setState(() {
      _step = _PinStep.current;
      _currentPin = '';
      _newPin = '';
      _confirmPin = '';
      _error = message;
    });
  }

  Future<void> _continue() async {
    if (_activeValue.length != 4 || _submitting) return;

    if (_step == _PinStep.current) {
      setState(() => _step = _PinStep.newPin);
      return;
    }

    if (_step == _PinStep.newPin) {
      if (_newPin == _currentPin) {
        setState(() {
          _error = 'New PIN must differ from the current one.';
          _newPin = '';
        });
        return;
      }
      setState(() => _step = _PinStep.confirmPin);
      return;
    }

    // confirmPin step
    if (_confirmPin != _newPin) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _confirmPin = '';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await AuthService.instance.changeTransactionPin(
        currentPin: _currentPin,
        newPin: _newPin,
        newPinConfirm: _confirmPin,
      );
      if (!mounted) return;
      context.read<UserSession>().setUser(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction PIN changed successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      _restart(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  ({String title, String subtitle}) get _copy {
    switch (_step) {
      case _PinStep.current:
        return (
          title: 'Enter Current PIN',
          subtitle: 'Enter your current 4 digit transaction PIN',
        );
      case _PinStep.newPin:
        return (
          title: 'Set New PIN',
          subtitle: 'Enter a new four digit transaction PIN',
        );
      case _PinStep.confirmPin:
        return (
          title: 'Confirm New PIN',
          subtitle: 'Enter the new PIN again to confirm',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final canContinue = _activeValue.length == 4;
    final copy = _copy;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
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
                      AuthTitleBlock(title: copy.title, subtitle: copy.subtitle),
                      const SizedBox(height: 40),
                      PinDotBoxes(length: 4, filledCount: _activeValue.length),
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
                        label: _step == _PinStep.confirmPin ? 'Confirm' : 'Continue',
                        enabled: canContinue,
                        loading: _submitting,
                        onPressed: _continue,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
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
