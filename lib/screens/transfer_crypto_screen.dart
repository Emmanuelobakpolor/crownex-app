import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/crypto.dart';
import '../services/api_exception.dart';
import '../services/crypto_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';

String _fmt(double v, {int decimals = 2}) {
  if (v == 0) return decimals == 0 ? '0' : '0.${'0' * decimals}';
  final fixed = v.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  if (decimals == 0) return buf.toString();
  return '${buf.toString()}.${parts[1]}';
}

String _fmtNgn(double v) => '₦${_fmt(v)}';

/// Transfer Crypto — an on-chain withdrawal. No quote/lock like buy/sell/
/// swap; the fee estimate is fetched live and re-confirmed at submission.
class TransferCryptoScreen extends StatefulWidget {
  const TransferCryptoScreen({super.key});

  @override
  State<TransferCryptoScreen> createState() => _TransferCryptoScreenState();
}

class _TransferCryptoScreenState extends State<TransferCryptoScreen> {
  final _crypto = CryptoService.instance;

  bool _cryptoMode = true;
  List<CryptoCoin> _coins = const [];
  bool _loadingCoins = true;
  String? _coinsError;

  CryptoCoin? _token;
  String? _network;
  final _addressController = TextEditingController();
  final _qtyController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadCoins() async {
    setState(() {
      _loadingCoins = true;
      _coinsError = null;
    });
    try {
      final coins = await _crypto.getPrices();
      if (!mounted) return;
      setState(() {
        _coins = coins;
        _loadingCoins = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _coinsError = e.message;
        _loadingCoins = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _coinsError = 'Could not load coins. Please try again.';
        _loadingCoins = false;
      });
    }
  }

  bool get _needsNetwork => _token != null && kCryptoCoinNetworks.containsKey(_token!.symbol);

  double? get _quantity {
    final raw = _qtyController.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool get _canContinue {
    if (!_cryptoMode) return false;
    final qty = _quantity;
    final address = _addressController.text.trim();
    return _token != null &&
        (!_needsNetwork || _network != null) &&
        address.length >= 10 &&
        qty != null &&
        qty > 0 &&
        !_submitting;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickToken() async {
    final selected = await _showOptionsSheet<CryptoCoin>(
      title: 'Select Token',
      items: _coins,
      labelOf: (t) => t.symbol.toUpperCase(),
      subtitleOf: (t) => t.name,
      isSelected: (t) => t.symbol == _token?.symbol,
      leadingOf: (t) => _TokenDot(coin: t, size: 32),
    );
    if (selected != null) {
      setState(() {
        _token = selected;
        _network = kCryptoCoinNetworks[selected.symbol]?.first;
      });
    }
  }

  Future<void> _pickNetwork() async {
    final options = _token != null ? kCryptoCoinNetworks[_token!.symbol] : null;
    if (options == null) return;
    final selected = await _showOptionsSheet<String>(
      title: 'Select Network',
      items: options,
      labelOf: (n) => n,
      isSelected: (n) => n == _network,
    );
    if (selected != null) setState(() => _network = selected);
  }

  Future<T?> _showOptionsSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelOf,
    String Function(T)? subtitleOf,
    required bool Function(T) isSelected,
    Widget Function(T)? leadingOf,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(8, 16, 8, 12 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: items.map((item) {
                    final selected = isSelected(item);
                    return ListTile(
                      leading: leadingOf?.call(item),
                      title: Text(
                        labelOf(item),
                        style: TextStyle(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                          color: selected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: subtitleOf != null
                          ? Text(
                              subtitleOf(item),
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            )
                          : null,
                      trailing: selected
                          ? const Icon(Icons.check_rounded, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(item),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    final token = _token!;
    final address = _addressController.text.trim();
    final qty = _quantity!;

    setState(() => _submitting = true);
    WithdrawEstimate estimate;
    try {
      estimate = await _crypto.estimateWithdrawal(coin: token.symbol, amount: qty);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack(e.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack('Something went wrong. Please try again.');
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _WithdrawSummarySheet(
        address: address,
        network: _network,
        estimate: estimate,
      ),
    );
    if (confirmed != true || !mounted) return;

    final pin = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => const _TransactionPinSheet(),
    );
    if (pin == null || !mounted) return;

    await _submitWithdrawal(token: token, address: address, amount: qty, pin: pin);
  }

  Future<void> _submitWithdrawal({
    required CryptoCoin token,
    required String address,
    required double amount,
    required String pin,
  }) async {
    setState(() => _submitting = true);
    try {
      final withdrawal = await _crypto.requestWithdrawal(
        coin: token.symbol,
        amount: amount,
        address: address,
        pin: pin,
        network: _network,
        idempotencyKey: _crypto.generateIdempotencyKey(),
      );
      if (!mounted) return;
      setState(() => _submitting = false);

      if (withdrawal.status == CryptoWithdrawalStatus.failed) {
        _showFailureDialog(
          withdrawal.note.isNotEmpty
              ? withdrawal.note
              : 'Your withdrawal could not be started. Please try again.',
        );
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        isDismissible: false,
        enableDrag: false,
        builder: (ctx) => _TransferSubmittedSheet(
          withdrawal: withdrawal,
          onDone: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pop();
          },
        ),
      );
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

  void _showFailureDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdrawal failed'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _Header(title: 'Transfer Crypto', onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CryptoFiatTabs(
                        cryptoMode: _cryptoMode,
                        onChanged: (crypto) => setState(() => _cryptoMode = crypto),
                      ),
                      const SizedBox(height: 22),
                      if (!_cryptoMode)
                        const _FiatPlaceholder()
                      else if (_loadingCoins)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_coinsError != null)
                        _ErrorState(message: _coinsError!, onRetry: _loadCoins)
                      else ...[
                        _SelectField(
                          value: _token?.symbol.toUpperCase(),
                          placeholder: 'Select Token',
                          onTap: _pickToken,
                          leading: _token != null ? _TokenDot(coin: _token!, size: 24) : null,
                        ),
                        if (_needsNetwork) ...[
                          const SizedBox(height: 14),
                          _SelectField(
                            value: _network,
                            placeholder: 'Select Network',
                            onTap: _pickNetwork,
                          ),
                        ],
                        const SizedBox(height: 14),
                        _TextInput(
                          controller: _addressController,
                          hint: 'Enter receiving wallet address',
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        _TextInput(
                          controller: _qtyController,
                          hint: 'Enter quantity to transfer',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomPad),
                child: Column(
                  children: [
                    AuthPrimaryButton(
                      label: 'Continue',
                      enabled: _canContinue,
                      loading: _submitting,
                      onPressed: _onContinue,
                    ),
                    const SizedBox(height: 12),
                    _SecondaryButton(
                      label: 'Cancel Transaction',
                      onPressed: () => Navigator.of(context).maybePop(),
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

// ─── Summary sheet (fresh fee estimate, not locked) ─────────────────────────

class _WithdrawSummarySheet extends StatelessWidget {
  const _WithdrawSummarySheet({
    required this.address,
    required this.network,
    required this.estimate,
  });

  final String address;
  final String? network;
  final WithdrawEstimate estimate;

  String _shortAddress(String a) {
    if (a.length <= 14) return a;
    return '${a.substring(0, 8)}........${a.substring(a.length - 5)}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final coin = estimate.coin.toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Transfer Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                child: const Icon(Icons.close_rounded, size: 24, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Please preview the details below for your transfer',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _DetailRow(label: 'Sending To:', value: _shortAddress(address)),
                const SizedBox(height: 14),
                _DetailRow(label: 'Token', value: coin),
                if (network != null) ...[
                  const SizedBox(height: 14),
                  _DetailRow(label: 'Network', value: network!),
                ],
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Amount:',
                  value: '${_fmt(estimate.amount, decimals: estimate.amount < 1 ? 6 : 2)} $coin',
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Network Fee:',
                  value: '${_fmt(estimate.feeCoin, decimals: estimate.feeCoin < 1 ? 6 : 2)} $coin',
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'You Send (Net):',
                  value: '${_fmt(estimate.netAmount, decimals: estimate.netAmount < 1 ? 6 : 2)} $coin',
                  valueBold: true,
                ),
                const SizedBox(height: 14),
                _DetailRow(label: 'Est. Value:', value: _fmtNgn(estimate.notionalNgn)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(label: 'Send Token', onPressed: () => Navigator.of(context).pop(true)),
          const SizedBox(height: 12),
          _SecondaryButton(
            label: 'Cancel Transfer',
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

// ─── PIN sheet ────────────────────────────────────────────────────────────────

class _TransactionPinSheet extends StatefulWidget {
  const _TransactionPinSheet();

  @override
  State<_TransactionPinSheet> createState() => _TransactionPinSheetState();
}

class _TransactionPinSheetState extends State<_TransactionPinSheet> {
  String _pin = '';

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _onProceed() {
    if (_pin.length != 4) return;
    Navigator.of(context).pop(_pin);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Enter Your Transaction PIN',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded, size: 24, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _pin.length;
              return Container(
                width: 52,
                height: 52,
                margin: EdgeInsets.only(right: i < 3 ? 12 : 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: filled ? AppColors.primary : AppColors.border,
                    width: filled ? 1.6 : 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: filled
                    ? Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              );
            }),
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter 4-digit PIN to confirm',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _PinKeypad(onDigit: _onDigit, onBackspace: _onBackspace),
          const SizedBox(height: 20),
          AuthPrimaryButton(
            label: 'Proceed',
            enabled: _pin.length == 4,
            onPressed: _onProceed,
          ),
        ],
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((key) {
              if (key.isEmpty) {
                return const Expanded(child: SizedBox(height: 48));
              }
              final isBack = key == '⌫';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: const Color(0xFFF5F6F8),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => isBack ? onBackspace() : onDigit(key),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: isBack
                              ? const Icon(
                                  Icons.backspace_outlined,
                                  size: 20,
                                  color: AppColors.textPrimary,
                                )
                              : Text(
                                  key,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Submitted (processing) sheet ────────────────────────────────────────────

class _TransferSubmittedSheet extends StatelessWidget {
  const _TransferSubmittedSheet({required this.withdrawal, required this.onDone});

  final CryptoWithdrawal withdrawal;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final coin = withdrawal.coin.toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF22C55E), width: 2),
            ),
            child: const Icon(Icons.check_rounded, size: 30, color: Color(0xFF16A34A)),
          ),
          const SizedBox(height: 18),
          const Text(
            'Withdrawal Submitted',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          const Text(
            'You sent',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fmt(withdrawal.netAmount, decimals: withdrawal.netAmount < 1 ? 6 : 2)} $coin',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFEEF0F4)),
                bottom: BorderSide(color: Color(0xFFEEF0F4)),
              ),
            ),
            child: Column(
              children: [
                _DetailRow(label: 'Sent To:', value: withdrawal.address),
                const SizedBox(height: 12),
                _DetailRow(label: 'Token', value: coin),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Network Fee',
                  value: '${_fmt(withdrawal.feeCoin, decimals: withdrawal.feeCoin < 1 ? 6 : 2)} $coin',
                ),
                const SizedBox(height: 12),
                _DetailRow(label: 'Reference', value: withdrawal.reference),
                const SizedBox(height: 12),
                const _DetailRow(
                  label: 'Status',
                  value: 'Processing',
                  valueBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your withdrawal is on its way. This can take a few minutes to confirm on-chain — '
            'check your transaction history for updates.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}

// ─── Shared widgets ──────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: AuthBackButton(onPressed: onBack)),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CryptoFiatTabs extends StatelessWidget {
  const _CryptoFiatTabs({required this.cryptoMode, required this.onChanged});

  final bool cryptoMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(label: 'Crypto', selected: cryptoMode, onTap: () => onChanged(true)),
          ),
          Expanded(
            child: _TabChip(label: 'Fiat', selected: !cryptoMode, onTap: () => onChanged(false)),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.leading,
  });

  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: Text(
                  has ? value! : placeholder,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                    color: has ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real coin icon from the backend's CoinCap-CDN logo_url, falling back to
/// a color+letter circle if the image fails to load.
class _TokenDot extends StatelessWidget {
  const _TokenDot({required this.coin, this.size = 28});

  final CryptoCoin coin;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.network(
        coin.logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: colorFromHex(coin.color), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            coin.letter,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4),
          ),
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueBold = false});

  final String label;
  final String value;
  final bool valueBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: valueBold ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: const Color(0xFFD6DEFF),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B6C9B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FiatPlaceholder extends StatelessWidget {
  const _FiatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.account_balance_rounded, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Fiat transfer coming soon',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Use the Crypto tab to send tokens for now.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
