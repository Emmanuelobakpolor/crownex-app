import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wallet.dart';
import '../services/api_exception.dart';
import '../services/wallet_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';

/// Hardcoded major Nigerian bank codes — used only if GET /wallet/banks/
/// (which proxies Flutterwave) is unreachable.
const _fallbackBanks = [
  Bank(name: 'Access Bank', code: '044'),
  Bank(name: 'Zenith Bank', code: '057'),
  Bank(name: 'Guaranty Trust Bank', code: '058'),
  Bank(name: 'United Bank for Africa', code: '033'),
  Bank(name: 'First Bank of Nigeria', code: '011'),
  Bank(name: 'Fidelity Bank', code: '070'),
  Bank(name: 'Union Bank of Nigeria', code: '032'),
  Bank(name: 'Sterling Bank', code: '232'),
  Bank(name: 'Wema Bank', code: '035'),
  Bank(name: 'Stanbic IBTC Bank', code: '221'),
  Bank(name: 'Ecobank Nigeria', code: '050'),
  Bank(name: 'First City Monument Bank', code: '214'),
  Bank(name: 'Heritage Bank', code: '030'),
  Bank(name: 'Keystone Bank', code: '082'),
  Bank(name: 'Providus Bank', code: '101'),
  Bank(name: 'Opay', code: '999992'),
  Bank(name: 'PalmPay', code: '999991'),
  Bank(name: 'Kuda Microfinance Bank', code: '50211'),
  Bank(name: 'Moniepoint MFB', code: '50515'),
];

/// Withdraw NGN to bank — bank picker, account resolve, amount, submit.
class WithdrawNgnScreen extends StatefulWidget {
  const WithdrawNgnScreen({super.key});

  @override
  State<WithdrawNgnScreen> createState() => _WithdrawNgnScreenState();
}

class _WithdrawNgnScreenState extends State<WithdrawNgnScreen> {
  final _wallet = WalletService.instance;
  final _amountController = TextEditingController();
  final _accountController = TextEditingController();
  final _amountFocus = FocusNode();

  bool _loadingBalance = true;
  double _availableBalance = 0;

  List<Bank> _banks = const [];

  Bank? _selectedBank;
  String? _resolvedAccountName;
  bool _verifying = false;
  String? _verifyError;

  bool _submitting = false;

  static const _quickAmounts = [1000, 2000, 5000, 10000, 20000, 50000];

  @override
  void initState() {
    super.initState();
    _loadBalance();
    _loadBanks();
    _accountController.addListener(_onAccountChanged);
  }

  @override
  void dispose() {
    _accountController.removeListener(_onAccountChanged);
    _amountController.dispose();
    _accountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final wallet = await _wallet.getWallet();
      if (!mounted) return;
      setState(() {
        _availableBalance = wallet.ngnBalance;
        _loadingBalance = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingBalance = false);
    }
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await _wallet.getBanks();
      if (!mounted) return;
      setState(() => _banks = banks.isNotEmpty ? banks : _fallbackBanks);
    } catch (_) {
      if (!mounted) return;
      setState(() => _banks = _fallbackBanks);
    }
  }

  void _onAccountChanged() {
    // Any edit to the account number invalidates a previous verification.
    if (_resolvedAccountName != null || _verifyError != null) {
      setState(() {
        _resolvedAccountName = null;
        _verifyError = null;
      });
    }
  }

  Future<void> _pickBank() async {
    final picked = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _BankPickerSheet(banks: _banks),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedBank = picked;
        _resolvedAccountName = null;
        _verifyError = null;
      });
    }
  }

  Future<void> _verifyAccount() async {
    final bank = _selectedBank;
    final accountNumber = _accountController.text.trim();
    if (bank == null || accountNumber.length != 10 || _verifying) return;

    setState(() {
      _verifying = true;
      _verifyError = null;
    });

    try {
      final name = await _wallet.resolveAccount(
        accountNumber: accountNumber,
        bankCode: bank.code,
      );
      if (!mounted) return;
      setState(() {
        _resolvedAccountName = name;
        _verifying = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifyError = e.message;
        _verifying = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifyError = 'Could not verify this account.';
        _verifying = false;
      });
    }
  }

  double? get _amount {
    final raw = _amountController.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String? get _amountHint {
    final amount = _amount;
    if (amount == null) return null;
    if (amount < 500) return 'Minimum withdrawal is ₦500';
    if (amount > _availableBalance) return 'Amount exceeds available balance';
    return null;
  }

  bool get _canSubmit {
    final amount = _amount;
    return _selectedBank != null &&
        _accountController.text.trim().length == 10 &&
        _resolvedAccountName != null &&
        amount != null &&
        amount >= 500 &&
        amount <= _availableBalance &&
        !_submitting;
  }

  void _selectQuickAmount(int value) {
    final capped = value > _availableBalance
        ? _availableBalance.floor()
        : value;
    if (capped < 500) return;
    _amountController.text = capped.toString();
    setState(() {});
    _amountFocus.unfocus();
  }

  void _setMaxAmount() {
    if (_availableBalance < 500) return;
    _amountController.text = _availableBalance.floor().toString();
    setState(() {});
    _amountFocus.unfocus();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final bank = _selectedBank!;
    final amount = _amount!;

    setState(() => _submitting = true);

    try {
      final reference = await _wallet.requestWithdrawal(
        amount: amount,
        accountName: _resolvedAccountName!,
        bankName: bank.name,
        bankCode: bank.code,
        accountNumber: _accountController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        // Optimistic — the real, final status arrives via webhook and shows
        // up in transaction history. This just keeps the balance display
        // in sync with what the server already debited.
        _availableBalance -= amount;
        _submitting = false;
      });

      await _showSuccessDialog(reference: reference, amount: amount);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack('Something went wrong. Please try again.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Future<void> _showSuccessDialog({
    required String reference,
    required double amount,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WithdrawSuccessDialog(
        amount: amount,
        reference: reference,
        bankName: _selectedBank?.name ?? '',
        accountName: _resolvedAccountName ?? '',
        onDone: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final amount = _amount;
    final amountHint = _amountHint;
    final selectedQuick = amount != null &&
            amount == amount.roundToDouble() &&
            _quickAmounts.contains(amount.round())
        ? amount.round()
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const _WithdrawHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BalanceCard(
                        loading: _loadingBalance,
                        balance: _availableBalance,
                      ),
                      const SizedBox(height: 16),
                      _AmountCard(
                        controller: _amountController,
                        focusNode: _amountFocus,
                        amountHint: amountHint,
                        onChanged: (_) => setState(() {}),
                        onMax: _setMaxAmount,
                        canMax: !_loadingBalance && _availableBalance >= 500,
                      ),
                      const SizedBox(height: 12),
                      _QuickAmountRow(
                        amounts: _quickAmounts,
                        selected: selectedQuick,
                        onSelected: _selectQuickAmount,
                      ),
                      const SizedBox(height: 24),
                      const _SectionLabel('Bank details'),
                      const SizedBox(height: 12),
                      _BankDetailsCard(
                        selectedBank: _selectedBank,
                        onPickBank: _pickBank,
                        accountController: _accountController,
                        verifying: _verifying,
                        verified: _resolvedAccountName != null,
                        onVerify: _verifyAccount,
                        resolvedName: _resolvedAccountName,
                        verifyError: _verifyError,
                        onAccountChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      const _InfoBanner(),
                    ],
                  ),
                ),
              ),
              _BottomBar(
                bottomPad: bottomPad,
                canSubmit: _canSubmit,
                submitting: _submitting,
                amount: amount,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatAmount(double v) {
  final s = v.toStringAsFixed(0);
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String _bankInitials(String name) {
  final parts = name
      .replaceAll(RegExp(r'\b(Bank|of|Nigeria|Microfinance|MFB)\b', caseSensitive: false), '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return name.isNotEmpty ? name[0].toUpperCase() : '?';
  if (parts.length == 1) {
    final w = parts.first;
    return w.length >= 2 ? w.substring(0, 2).toUpperCase() : w.toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _WithdrawHeader extends StatelessWidget {
  const _WithdrawHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AuthBackButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Withdraw NGN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Send money to your bank',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Balance card ───────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.loading,
    required this.balance,
  });

  final bool loading;
  final double balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryGradientEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available balance',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: loading
                      ? Text(
                          key: const ValueKey('loading'),
                          'Loading…',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: -0.4,
                          ),
                        )
                      : Text(
                          key: const ValueKey('balance'),
                          '₦${_formatAmount(balance)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.6,
                          ),
                        ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'NGN',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Amount card ────────────────────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onMax,
    required this.canMax,
    this.amountHint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onMax;
  final bool canMax;
  final String? amountHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.south_west_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Withdrawal amount',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canMax ? onMax : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: canMax
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: canMax
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.border,
                      ),
                    ),
                    child: Text(
                      'Max',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: canMax
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: onChanged,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -1.2,
              height: 1.1,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted.withValues(alpha: 0.45),
                letterSpacing: -1.2,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(right: 4, top: 6),
                child: Text(
                  '₦',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              amountHint ?? 'Minimum ₦500 · Arrives within 24 hours',
              key: ValueKey(amountHint ?? 'default'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: amountHint != null
                    ? const Color(0xFFDC2626)
                    : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick amounts ──────────────────────────────────────────────────────────

class _QuickAmountRow extends StatelessWidget {
  const _QuickAmountRow({
    required this.amounts,
    required this.selected,
    required this.onSelected,
  });

  final List<int> amounts;
  final int? selected;
  final ValueChanged<int> onSelected;

  String _label(int value) {
    if (value >= 1000) {
      final k = value / 1000;
      return k == k.roundToDouble()
          ? '₦${k.toInt()}k'
          : '₦${k.toStringAsFixed(1)}k';
    }
    return '₦$value';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: amounts.map((amount) {
        final isSelected = selected == amount;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelected(amount),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                _label(amount),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ─── Bank details card ──────────────────────────────────────────────────────

class _BankDetailsCard extends StatelessWidget {
  const _BankDetailsCard({
    required this.selectedBank,
    required this.onPickBank,
    required this.accountController,
    required this.verifying,
    required this.verified,
    required this.onVerify,
    required this.onAccountChanged,
    this.resolvedName,
    this.verifyError,
  });

  final Bank? selectedBank;
  final VoidCallback onPickBank;
  final TextEditingController accountController;
  final bool verifying;
  final bool verified;
  final VoidCallback onVerify;
  final ValueChanged<String> onAccountChanged;
  final String? resolvedName;
  final String? verifyError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bank',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _BankSelector(bank: selectedBank, onTap: onPickBank),
          const SizedBox(height: 16),
          const Text(
            'Account number',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _Field(
            controller: accountController,
            hint: '0123456789',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: onAccountChanged,
            suffix: _AccountVerifySuffix(
              enabled: selectedBank != null &&
                  accountController.text.trim().length == 10,
              verifying: verifying,
              verified: verified,
              onVerify: onVerify,
            ),
          ),
          if (resolvedName != null) ...[
            const SizedBox(height: 12),
            _VerifiedNameBanner(name: resolvedName!),
          ] else if (verifyError != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: verifyError!),
          ],
        ],
      ),
    );
  }
}

class _VerifiedNameBanner extends StatelessWidget {
  const _VerifiedNameBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.verified_rounded,
              size: 18,
              color: Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Account verified',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFDC2626),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFFDC2626),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info banner ────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Verify your account before withdrawing. Funds usually arrive '
              'within a few minutes, and at most 24 hours.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom bar ─────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.bottomPad,
    required this.canSubmit,
    required this.submitting,
    required this.onSubmit,
    this.amount,
  });

  final double bottomPad;
  final bool canSubmit;
  final bool submitting;
  final VoidCallback onSubmit;
  final double? amount;

  @override
  Widget build(BuildContext context) {
    final label = amount != null && canSubmit
        ? 'Withdraw ₦${_formatAmount(amount!)}'
        : 'Withdraw';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: AuthPrimaryButton(
        label: label,
        enabled: canSubmit,
        loading: submitting,
        onPressed: onSubmit,
      ),
    );
  }
}

// ─── Bank selector ──────────────────────────────────────────────────────────

class _BankSelector extends StatelessWidget {
  const _BankSelector({required this.bank, required this.onTap});

  final Bank? bank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          child: Row(
            children: [
              if (bank != null) ...[
                _BankAvatar(name: bank!.name, size: 36),
                const SizedBox(width: 12),
              ] else ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  bank?.name ?? 'Select bank',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight:
                        bank == null ? FontWeight.w500 : FontWeight.w600,
                    color: bank == null
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BankAvatar extends StatelessWidget {
  const _BankAvatar({required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.14),
            AppColors.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        _bankInitials(name),
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _AccountVerifySuffix extends StatelessWidget {
  const _AccountVerifySuffix({
    required this.enabled,
    required this.verifying,
    required this.verified,
    required this.onVerify,
  });

  final bool enabled;
  final bool verifying;
  final bool verified;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    if (verifying) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }
    if (verified) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Icon(Icons.check_circle_rounded, color: Color(0xFF059669)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton(
        onPressed: enabled ? onVerify : null,
        style: TextButton.styleFrom(
          backgroundColor: enabled
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          foregroundColor:
              enabled ? AppColors.primary : AppColors.textMuted,
          disabledForegroundColor: AppColors.textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Verify',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

// ─── Bank picker sheet ──────────────────────────────────────────────────────

class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet({required this.banks});

  final List<Bank> banks;

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.banks
        .where((b) => b.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final bottom = MediaQuery.paddingOf(context).bottom;

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Select Bank',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.banks.length} banks available',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search banks',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: widget.banks.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 40,
                                color: AppColors.textMuted.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'No banks found',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: Color(0xFFEEF0F4),
                          ),
                          itemBuilder: (_, i) {
                            final bank = filtered[i];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => Navigator.of(context).pop(bank),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      _BankAvatar(name: bank.name),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          bank.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textMuted,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Success dialog ─────────────────────────────────────────────────────────

class _WithdrawSuccessDialog extends StatelessWidget {
  const _WithdrawSuccessDialog({
    required this.amount,
    required this.reference,
    required this.bankName,
    required this.accountName,
    required this.onDone,
  });

  final double amount;
  final String reference;
  final String bankName;
  final String accountName;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0.06),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: AppColors.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Withdrawal Initiated',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₦${_formatAmount(amount)} is on its way. It typically arrives '
              'within 24 hours.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14.5,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (accountName.isNotEmpty)
                    _SuccessDetailRow(
                      label: 'To',
                      value: accountName,
                    ),
                  if (bankName.isNotEmpty) ...[
                    if (accountName.isNotEmpty) const SizedBox(height: 10),
                    _SuccessDetailRow(
                      label: 'Bank',
                      value: bankName,
                    ),
                  ],
                  if (accountName.isNotEmpty || bankName.isNotEmpty)
                    const SizedBox(height: 10),
                  _SuccessDetailRow(
                    label: 'Reference',
                    value: reference,
                    mono: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            AuthPrimaryButton(label: 'Done', onPressed: onDone),
          ],
        ),
      ),
    );
  }
}

class _SuccessDetailRow extends StatelessWidget {
  const _SuccessDetailRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: mono ? 12 : 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: mono ? -0.2 : 0,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Field ──────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.keyboardType,
    this.suffix,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.4,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
