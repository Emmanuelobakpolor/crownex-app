import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'set_transaction_pin_screen.dart';

/// Step 3 of signup — full name + password.
class SetupProfileScreen extends StatefulWidget {
  const SetupProfileScreen({
    super.key,
    required this.email,
    required this.phone,
  });

  final String email;
  final String phone;

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _canSubmit = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_revalidate);
    _passwordController.addListener(_revalidate);
    _confirmController.addListener(_revalidate);
  }

  void _revalidate() {
    final name = _nameController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmController.text;
    final ok = name.length >= 2 &&
        pass.length >= 8 &&
        confirm.isNotEmpty &&
        pass == confirm;
    if (ok != _canSubmit) {
      setState(() => _canSubmit = ok);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();

    setState(() => _loading = true);
    try {
      await AuthService.instance.completeProfile(
        email: widget.email,
        fullName: name,
        password: _passwordController.text,
        passwordConfirm: _confirmController.text,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SetTransactionPinScreen(
            fullName: name,
            email: widget.email,
            phone: widget.phone,
          ),
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
              const AuthAppHeader(currentStep: 3),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AuthTitleBlock(
                          title: 'Set Up Profile',
                          subtitle:
                              'Enter full name and password for your account',
                        ),
                        const SizedBox(height: 36),
                        const AuthFieldLabel('Full Name'),
                        AuthTextField(
                          controller: _nameController,
                          hintText: 'Enter preferred username',
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your full name';
                            }
                            if (value.trim().length < 2) {
                              return 'Name is too short';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        const AuthFieldLabel('Password'),
                        AuthTextField(
                          controller: _passwordController,
                          hintText: 'Enter password',
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textMuted,
                              size: 22,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscurePassword = !_obscurePassword,
                              );
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Create a password';
                            }
                            if (value.length < 8) {
                              return 'Must be at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Must be at least 8 characters.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const AuthFieldLabel('Confirm Password'),
                        AuthTextField(
                          controller: _confirmController,
                          hintText: 'Enter password',
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textMuted,
                              size: 22,
                            ),
                            onPressed: () {
                              setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              );
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
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
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottomPad),
                child: AuthPrimaryButton(
                  label: 'Create account',
                  enabled: _canSubmit,
                  loading: _loading,
                  onPressed: _createAccount,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
