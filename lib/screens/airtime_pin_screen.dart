import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_exception.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'airtime_processing_screen.dart';

/// Transaction PIN entry before a purchase is submitted.
///
/// When [onSubmit] is provided, a single PIN entry is sent straight to the
/// backend for verification + purchase. Screens not yet wired to a real
/// backend keep the legacy create-then-confirm placeholder flow instead.
class AirtimePinScreen extends StatefulWidget {
  const AirtimePinScreen({
    super.key,
    required this.amount,
    required this.phone,
    required this.networkName,
    this.existingPin,
    this.onSubmit,
  });

  final double amount;
  final String phone;
  final String networkName;

  /// When set, this is the confirm step of the legacy placeholder flow.
  final String? existingPin;

  /// When provided, the entered PIN is sent here to perform the real
  /// purchase instead of running the legacy create/confirm placeholder.
  final Future<void> Function(String pin)? onSubmit;

  bool get isConfirm => existingPin != null;

  @override
  State<AirtimePinScreen> createState() => _AirtimePinScreenState();
}

class _AirtimePinScreenState extends State<AirtimePinScreen> {
  String _pin = '';
  String? _error;

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) {
      Future<void>.delayed(const Duration(milliseconds: 120), _submit);
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_pin.length != 4 || !mounted) return;

    if (widget.onSubmit != null) {
      final pin = _pin;
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => AirtimeProcessingScreen(future: _runSubmit(pin)),
        ),
      );
      if (ok == true && mounted) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() => _pin = '');
      }
      return;
    }

    if (!widget.isConfirm) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => AirtimePinScreen(
            amount: widget.amount,
            phone: widget.phone,
            networkName: widget.networkName,
            existingPin: _pin,
          ),
        ),
      );
      if (result == true && mounted) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        setState(() => _pin = '');
      }
      return;
    }

    if (_pin != widget.existingPin) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _pin = '';
      });
      return;
    }

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const AirtimeProcessingScreen(),
      ),
    );

    if (ok == true && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      setState(() => _pin = '');
    }
  }

  Future<bool> _runSubmit(String pin) async {
    try {
      await widget.onSubmit!(pin);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
      return false;
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
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AuthBackButton(
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const Text(
                        'Transaction Pin',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    Text(
                      widget.onSubmit != null
                          ? 'Enter your PIN'
                          : widget.isConfirm
                              ? 'Confirm your pin'
                              : 'Create your pin',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.onSubmit != null
                          ? 'Enter your 4-digit transaction PIN to confirm this payment'
                          : 'Set a 4-digit pin for your virtual card',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _CompactPinDots(filled: _pin.length),
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
                    const Spacer(flex: 3),
                  ],
                ),
              ),
              _SoftKeypad(
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

class _CompactPinDots extends StatelessWidget {
  const _CompactPinDots({required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final isFilled = i < filled;
        return Container(
          margin: EdgeInsets.only(right: i < 3 ? 12 : 0),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isFilled
              ? const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 10, height: 10),
                  ),
                )
              : null,
        );
      }),
    );
  }
}

class _SoftKeypad extends StatelessWidget {
  const _SoftKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.bottomInset,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final rows = <List<String>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];

    return Container(
      color: const Color(0xFFD1D3D9),
      padding: EdgeInsets.fromLTRB(4, 6, 4, 6 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: row.map((key) {
                if (key.isEmpty) {
                  return const Expanded(child: SizedBox(height: 48));
                }
                if (key == 'back') {
                  return Expanded(
                    child: _Key(
                      onTap: onBackspace,
                      child: const Icon(
                        Icons.backspace_outlined,
                        size: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  );
                }
                return Expanded(
                  child: _Key(
                    onTap: () => onDigit(key),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          key,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                        ),
                        if (_letters(key).isNotEmpty)
                          Text(
                            _letters(key),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              letterSpacing: 1,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _letters(String key) {
    const map = {
      '2': 'ABC',
      '3': 'DEF',
      '4': 'GHI',
      '5': 'JKL',
      '6': 'MNO',
      '7': 'PQRS',
      '8': 'TUV',
      '9': 'WXYZ',
    };
    return map[key] ?? '';
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(height: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}
