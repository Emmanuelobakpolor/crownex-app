import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/crypto.dart';
import '../services/api_exception.dart';
import '../services/crypto_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';

String _fmt(double v, {int? decimals}) {
  if (v == 0) return '0.00';
  final d = decimals ?? (v >= 1000 ? 0 : (v >= 1 ? 2 : 6));
  final fixed = v.toStringAsFixed(d);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  if (parts.length == 1 || d == 0) return buf.toString();
  var frac = parts[1];
  if (v < 1) {
    while (frac.endsWith('0') && frac.length > 2) {
      frac = frac.substring(0, frac.length - 1);
    }
  }
  return '${buf.toString()}.$frac';
}

String _fmtNgn(double v) => '₦${_fmt(v, decimals: 2)}';

/// Swap Crypto — real quote (locked rate + fee) -> PIN -> order.
class SwapCryptoScreen extends StatefulWidget {
  const SwapCryptoScreen({super.key});

  @override
  State<SwapCryptoScreen> createState() => _SwapCryptoScreenState();
}

class _SwapCryptoScreenState extends State<SwapCryptoScreen> {
  final _crypto = CryptoService.instance;

  List<CryptoCoin> _coins = const [];
  Map<String, double> _balances = const {};
  bool _loading = true;
  String? _loadError;

  CryptoCoin? _fromToken;
  CryptoCoin? _toToken;
  final _amountController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([_crypto.getPrices(), _crypto.getWallets()]);
      if (!mounted) return;
      final coins = results[0] as List<CryptoCoin>;
      final wallets = results[1] as List<CryptoWalletBalance>;
      setState(() {
        _coins = coins;
        _balances = {for (final w in wallets) w.coin: w.available};
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load data. Please try again.';
        _loading = false;
      });
    }
  }

  double? get _amount {
    final raw = _amountController.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  bool get _canSwap {
    final amt = _amount;
    if (_fromToken == null || _toToken == null || amt == null) return false;
    if (_fromToken!.symbol == _toToken!.symbol) return false;
    return amt > 0 && !_submitting;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickToken({required bool isFrom}) async {
    final selected = await showModalBottomSheet<CryptoCoin>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _TokenPickerSheet(
        tokens: _coins,
        balances: _balances,
        selected: isFrom ? _fromToken : _toToken,
        exclude: isFrom ? _toToken : _fromToken,
      ),
    );
    if (selected == null) return;
    setState(() {
      if (isFrom) {
        _fromToken = selected;
        if (_toToken?.symbol == selected.symbol) _toToken = null;
      } else {
        _toToken = selected;
        if (_fromToken?.symbol == selected.symbol) _fromToken = null;
      }
    });
  }

  void _flipTokens() {
    setState(() {
      final tmp = _fromToken;
      _fromToken = _toToken;
      _toToken = tmp;
    });
  }

  Future<void> _onSwap() async {
    if (!_canSwap) return;
    final coin = _fromToken!.symbol;
    final toCoin = _toToken!.symbol;
    final amount = _amount!;

    setState(() => _submitting = true);
    try {
      final quote = await _crypto.createQuote(
        type: 'swap',
        coin: coin,
        amount: amount,
        toCoin: toCoin,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await _showQuoteSheet(quote);
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

  Future<void> _showQuoteSheet(CryptoQuote quote) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _SwapQuoteSheet(quote: quote),
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

    await _submitSwap(quote, pin);
  }

  Future<void> _submitSwap(CryptoQuote quote, String pin) async {
    setState(() => _submitting = true);
    try {
      final order = await _crypto.placeSwapOrder(
        quoteId: quote.id,
        pin: pin,
        idempotencyKey: _crypto.generateIdempotencyKey(),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      _refreshBalances();

      if (order.status == CryptoOrderStatus.completed) {
        await _showSuccessSheet(order);
      } else if (order.refundedNgn != null) {
        _showResultDialog(
          title: 'Swap refunded',
          icon: Icons.account_balance_wallet_outlined,
          color: const Color(0xFFF59E0B),
          message: order.note.isNotEmpty
              ? order.note
              : "We couldn't complete your swap, so ₦${order.refundedNgn!.toStringAsFixed(2)} "
                  'was added to your NGN wallet instead.',
        );
      } else if (order.status == CryptoOrderStatus.processing) {
        _showResultDialog(
          title: 'Swap processing',
          icon: Icons.hourglass_top_rounded,
          color: AppColors.primary,
          message: "We're confirming your swap with our provider. Your balance will update "
              "automatically once it's done — no need to try again.",
        );
      } else {
        _showResultDialog(
          title: 'Swap failed',
          icon: Icons.error_outline_rounded,
          color: const Color(0xFFDC2626),
          message: order.note.isNotEmpty ? order.note : 'Your swap could not be completed.',
        );
      }
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

  Future<void> _showSuccessSheet(CryptoOrder order) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => _SwapSuccessSheet(
        order: order,
        onDone: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  /// Re-reads wallet balances without the full-screen loader, so the
  /// "Balance" line reflects what the swap just debited/credited.
  Future<void> _refreshBalances() async {
    try {
      final wallets = await _crypto.getWallets();
      if (!mounted) return;
      setState(() => _balances = {for (final w in wallets) w.coin: w.available});
    } catch (_) {
      // Stale balance until the next visit is fine.
    }
  }

  void _showResultDialog({
    required String title,
    required IconData icon,
    required Color color,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(icon, color: color, size: 40),
        title: Text(title, textAlign: TextAlign.center),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _onCancel() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final fromBalance = _fromToken != null
        ? 'Balance ${_fmt(_balances[_fromToken!.symbol] ?? 0)} ${_fromToken!.symbol.toUpperCase()}'
        : 'Balance 0.0';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _Header(title: 'Swap Crypto', onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _loadError != null
                          ? _ErrorState(message: _loadError!, onRetry: _load)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Swap From:',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      fromBalance,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _TokenSelectField(
                                  token: _fromToken,
                                  onTap: () => _pickToken(isFrom: true),
                                ),
                                const SizedBox(height: 12),
                                _AmountField(
                                  controller: _amountController,
                                  onChanged: (_) => setState(() {}),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Material(
                                    color: const Color(0xFFEEF2FF),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: _flipTokens,
                                      child: const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: Icon(
                                          Icons.swap_vert_rounded,
                                          color: AppColors.primary,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Swap To:',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _TokenSelectField(
                                  token: _toToken,
                                  onTap: () => _pickToken(isFrom: false),
                                ),
                              ],
                            ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomPad),
                child: Column(
                  children: [
                    AuthPrimaryButton(
                      label: 'Swap Token',
                      enabled: _canSwap,
                      loading: _submitting,
                      onPressed: _onSwap,
                    ),
                    const SizedBox(height: 12),
                    _SecondaryButton(label: 'Cancel Transaction', onPressed: _onCancel),
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

// ─── Quote summary (live countdown) ──────────────────────────────────────────

class _SwapQuoteSheet extends StatefulWidget {
  const _SwapQuoteSheet({required this.quote});

  final CryptoQuote quote;

  @override
  State<_SwapQuoteSheet> createState() => _SwapQuoteSheetState();
}

class _SwapQuoteSheetState extends State<_SwapQuoteSheet> {
  late int _secondsLeft = widget.quote.expiresIn;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final quote = widget.quote;
    final expired = _secondsLeft <= 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Confirm Swap',
                  style: TextStyle(
                    fontSize: 20,
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
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: expired ? const Color(0xFFDC2626) : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                expired ? 'Quote expired' : 'Rate locked for ${_secondsLeft}s',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: expired ? const Color(0xFFDC2626) : AppColors.textSecondary,
                ),
              ),
            ],
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
                _SummaryRow(
                  label: 'Swap ${quote.coin.toUpperCase()}:',
                  value: _fmt(quote.coinAmount, decimals: quote.coinAmount < 1 ? 6 : 2),
                ),
                const SizedBox(height: 14),
                _SummaryRow(
                  label: 'Receive ${quote.toCoin.toUpperCase()}:',
                  value: _fmt(quote.toCoinAmount ?? 0, decimals: (quote.toCoinAmount ?? 0) < 1 ? 6 : 2),
                ),
                const SizedBox(height: 14),
                _SummaryRow(label: 'Fee:', value: _fmtNgn(quote.feeNgn)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Confirm Swap',
            enabled: !expired,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 12),
          _SecondaryButton(label: 'Cancel', onPressed: () => Navigator.of(context).pop(false)),
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

// ─── Token picker ────────────────────────────────────────────────────────────

class _TokenPickerSheet extends StatefulWidget {
  const _TokenPickerSheet({
    required this.tokens,
    required this.balances,
    required this.selected,
    this.exclude,
  });

  final List<CryptoCoin> tokens;
  final Map<String, double> balances;
  final CryptoCoin? selected;
  final CryptoCoin? exclude;

  @override
  State<_TokenPickerSheet> createState() => _TokenPickerSheetState();
}

class _TokenPickerSheetState extends State<_TokenPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final filtered = widget.tokens.where((t) {
      if (widget.exclude?.symbol == t.symbol) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return t.symbol.toLowerCase().contains(q) || t.name.toLowerCase().contains(q);
    }).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 12 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Select Token',
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
          const SizedBox(height: 6),
          const Text(
            "Kindly select the token you'll love to swap",
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search token name',
              hintStyle: const TextStyle(fontSize: 15, color: AppColors.textMuted),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F6F8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFEEF0F4)),
              itemBuilder: (context, index) {
                final token = filtered[index];
                final selected = widget.selected?.symbol == token.symbol;
                final balance = widget.balances[token.symbol] ?? 0;
                return InkWell(
                  onTap: () => Navigator.of(context).pop(token),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        _TokenAvatar(coin: token, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                token.symbol.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                token.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _fmt(balance),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.border,
                              width: selected ? 6 : 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Success ─────────────────────────────────────────────────────────────────

class _SwapSuccessSheet extends StatelessWidget {
  const _SwapSuccessSheet({required this.order, required this.onDone});

  final CryptoOrder order;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 32, 24, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2.5),
            ),
            child: const Icon(Icons.check_rounded, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Swap Successful!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your transaction has been completed, you\n'
            'have successfully swapped your tokens.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.45, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '${order.coin.toUpperCase()} → ${order.toCoin.toUpperCase()}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

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

/// Real coin icon from the backend's CoinCap-CDN logo_url, falling back to
/// a color+letter circle if the image fails to load.
class _TokenAvatar extends StatelessWidget {
  const _TokenAvatar({required this.coin, this.size = 28});

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

class _TokenSelectField extends StatelessWidget {
  const _TokenSelectField({required this.token, required this.onTap});

  final CryptoCoin? token;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = token != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(
            children: [
              if (has) ...[
                _TokenAvatar(coin: token!, size: 28),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  has ? token!.symbol.toUpperCase() : 'Select Token',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: has ? FontWeight.w700 : FontWeight.w400,
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

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Enter amount',
        hintStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
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
