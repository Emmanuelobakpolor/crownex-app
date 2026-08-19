import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterwave_standard/flutterwave.dart';
import 'package:image_picker/image_picker.dart';

import '../models/crypto.dart';
import '../services/api_exception.dart';
import '../services/crypto_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'deposit_crypto_screen.dart';
import 'swap_crypto_screen.dart';
import 'transfer_crypto_screen.dart';

String _fmtNum(double v, {int decimals = 2}) {
  if (v == 0) return decimals == 0 ? '0' : '0.00';
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

String _fmtNgn(double v) => '₦${_fmtNum(v)}';

/// Crypto — buy & sell order flows, wired to the real quote -> order -> pay
/// pipeline (see crypto_service.dart).
class CryptoScreen extends StatefulWidget {
  const CryptoScreen({super.key, this.initialBuyMode = true});

  final bool initialBuyMode;

  @override
  State<CryptoScreen> createState() => _CryptoScreenState();
}

class _CryptoScreenState extends State<CryptoScreen> {
  final _crypto = CryptoService.instance;

  late bool _buyMode = widget.initialBuyMode;
  List<CryptoCoin> _coins = const [];
  bool _loadingCoins = true;
  String? _coinsError;

  CryptoCoin? _token;
  final _qtyController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  @override
  void dispose() {
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

  double? get _quantity {
    final raw = _qtyController.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  double get _estimatedTotal {
    final q = _quantity;
    final rate = _token?.rateNgn;
    if (q == null || rate == null) return 0;
    return q * rate;
  }

  bool get _canContinue {
    final q = _quantity;
    return _token != null && q != null && q > 0 && !_submitting;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickToken() async {
    final selected = await showModalBottomSheet<CryptoCoin>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _TokenPickerSheet(tokens: _coins, selected: _token),
    );
    if (selected != null) {
      setState(() => _token = selected);
    }
  }

  Future<void> _onContinue() async {
    if (!_canContinue || _token == null) return;
    final qty = _quantity!;
    final type = _buyMode ? 'buy' : 'sell';

    setState(() => _submitting = true);
    try {
      final quote = await _crypto.createQuote(type: type, coin: _token!.symbol, amount: qty);
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
      builder: (ctx) => _QuoteSummarySheet(quote: quote, buyMode: _buyMode),
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

    await _submitOrder(quote, pin);
  }

  Future<void> _submitOrder(CryptoQuote quote, String pin) async {
    setState(() => _submitting = true);
    final idempotencyKey = _crypto.generateIdempotencyKey();
    try {
      if (_buyMode) {
        final result = await _crypto.placeBuyOrder(
          quoteId: quote.id,
          pin: pin,
          idempotencyKey: idempotencyKey,
        );
        if (!mounted) return;
        setState(() => _submitting = false);
        await _handleBuyResult(result);
      } else {
        final result = await _crypto.placeSellOrder(
          quoteId: quote.id,
          pin: pin,
          idempotencyKey: idempotencyKey,
        );
        if (!mounted) return;
        setState(() => _submitting = false);
        await _handleSellResult(result);
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

  Future<void> _handleBuyResult(CryptoBuyResult result) async {
    final order = result.order;
    if (!result.needsPayment) {
      if (order.status == CryptoOrderStatus.completed) {
        await _showSuccessSheet(isSell: false, order: order);
      } else {
        _showFailureDialog(
          order.note.isNotEmpty ? order.note : 'Your purchase could not be completed.',
        );
      }
      return;
    }

    if (result.paymentMethod == 'flutterwave' && result.flutterwave != null) {
      await _payWithFlutterwave(order, result.flutterwave!);
    } else if (result.paymentMethod == 'bank_transfer') {
      await _showBankTransferSheet(order, result.bankDetails);
    } else {
      _showFailureDialog('Payment is not currently available. Please contact support.');
    }
  }

  Future<void> _handleSellResult(CryptoSellResult result) async {
    final order = result.order;
    if (result.waitingDeposit) {
      _showWaitingDepositDialog(order);
      return;
    }
    if (order.status == CryptoOrderStatus.completed) {
      await _showSuccessSheet(isSell: true, order: order);
    } else {
      _showFailureDialog(
        order.note.isNotEmpty ? order.note : 'Your sale could not be completed.',
      );
    }
  }

  Future<void> _payWithFlutterwave(CryptoOrder order, FlutterwaveInit init) async {
    final isTestMode = init.publicKey.contains('TEST');
    final flutterwave = Flutterwave(
      publicKey: init.publicKey,
      currency: 'NGN',
      redirectUrl: 'https://flutterwave.com',
      txRef: init.txRef,
      amount: init.amount.toStringAsFixed(2),
      customer: Customer(
        name: init.customerName,
        phoneNumber: init.customerPhone,
        email: init.customerEmail,
      ),
      paymentOptions: 'card,banktransfer,ussd',
      customization: Customization(
        title: 'CrownEx Crypto Buy',
        description: '${order.coinAmount} ${order.coin.toUpperCase()}',
      ),
      isTestMode: isTestMode,
    );

    final response = await flutterwave.charge(context);
    if (!mounted) return;

    if (response.success != true) {
      _showSnack(
        response.status == 'cancelled'
            ? 'Payment cancelled.'
            : 'Payment failed. Please try again.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final verified = await _crypto.verifyBuyPayment(order.reference);
      if (!mounted) return;
      setState(() => _submitting = false);
      if (verified.status == CryptoOrderStatus.completed) {
        await _showSuccessSheet(isSell: false, order: verified);
      } else {
        _showFailureDialog(
          verified.note.isNotEmpty
              ? verified.note
              : 'Payment received, but the purchase could not be completed. '
                  'Please contact support with reference ${order.reference}.',
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnack(e.message);
    }
  }

  Future<void> _showBankTransferSheet(CryptoOrder order, CryptoBankDetails? bank) async {
    final uploaded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _BankTransferSheet(order: order, bank: bank),
    );
    if (uploaded == true && mounted) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CryptoPendingReviewScreen(reference: order.reference),
        ),
      );
    }
  }

  Future<void> _showSuccessSheet({required bool isSell, required CryptoOrder order}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => _PurchaseSuccessSheet(
        isSell: isSell,
        order: order,
        onDone: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  void _showFailureDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transaction failed'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showWaitingDepositDialog(CryptoOrder order) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insufficient balance'),
        content: Text(
          "You don't have enough ${order.coin.toUpperCase()} to complete this sale. "
          'Deposit more and retry from your order history.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const DepositCryptoScreen()),
              );
            },
            child: const Text('Deposit'),
          ),
        ],
      ),
    );
  }

  void _onCancel() {
    Navigator.of(context).maybePop();
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
              _Header(title: 'Crypto', onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BuySellTabs(
                        buyMode: _buyMode,
                        onChanged: (buy) {
                          setState(() {
                            _buyMode = buy;
                            _qtyController.clear();
                            _token = null;
                          });
                        },
                        onSwap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const SwapCryptoScreen()),
                          );
                        },
                        onTransfer: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const TransferCryptoScreen()),
                          );
                        },
                        onDeposit: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => const DepositCryptoScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      if (_loadingCoins)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_coinsError != null)
                        _ErrorState(message: _coinsError!, onRetry: _loadCoins)
                      else ...[
                        _SelectTokenField(token: _token, onTap: _pickToken),
                        const SizedBox(height: 16),
                        _QtyField(
                          controller: _qtyController,
                          hint: _buyMode ? 'Enter quantity to buy' : 'Enter quantity to sell',
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 16),
                        _InfoChip(
                          label: _token?.rateNgn != null
                              ? 'Rate: ${_fmtNgn(_token!.rateNgn!)}'
                              : 'Select a token to see the live rate',
                        ),
                        const SizedBox(height: 12),
                        _InfoChip(
                          label: 'Estimated total: ${_fmtNgn(_estimatedTotal)}'
                              ' (fees applied at confirmation)',
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

// ─── Pending admin review (bank-transfer buys) ───────────────────────────────

class CryptoPendingReviewScreen extends StatelessWidget {
  const CryptoPendingReviewScreen({super.key, required this.reference});

  final String reference;

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
              _Header(title: 'Crypto', onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hourglass_top_rounded, size: 56, color: AppColors.primary),
                      const SizedBox(height: 28),
                      const Text(
                        'Awaiting Payment Review',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D1B4E),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Reference: $reference',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Our team will confirm your bank transfer and credit your wallet '
                        'shortly. You can track this order from your transaction history.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomPad),
                child: AuthPrimaryButton(
                  label: 'Go Back Home',
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
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

class _QuoteSummarySheet extends StatefulWidget {
  const _QuoteSummarySheet({required this.quote, required this.buyMode});

  final CryptoQuote quote;
  final bool buyMode;

  @override
  State<_QuoteSummarySheet> createState() => _QuoteSummarySheetState();
}

class _QuoteSummarySheetState extends State<_QuoteSummarySheet> {
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
    final decimals = quote.coinAmount < 1 ? 6 : 2;

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
              Expanded(
                child: Text(
                  widget.buyMode ? 'Buy Order' : 'Sell Order',
                  style: const TextStyle(
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
                _OrderRow(label: 'Token:', value: quote.coin.toUpperCase()),
                const SizedBox(height: 12),
                _OrderRow(label: 'Rate:', value: _fmtNgn(quote.rateNgn)),
                const SizedBox(height: 12),
                _OrderRow(
                  label: 'Quantity:',
                  value: _fmtNum(quote.coinAmount, decimals: decimals),
                ),
                const SizedBox(height: 12),
                _OrderRow(label: 'Fee:', value: _fmtNgn(quote.feeNgn)),
                const SizedBox(height: 12),
                _OrderRow(
                  label: widget.buyMode ? 'Total NGN To Pay:' : 'Total NGN To Receive:',
                  value: _fmtNgn(quote.totalNgn),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Confirm',
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

// ─── Bank transfer (buy) ──────────────────────────────────────────────────────

class _BankTransferSheet extends StatefulWidget {
  const _BankTransferSheet({required this.order, this.bank});

  final CryptoOrder order;
  final CryptoBankDetails? bank;

  @override
  State<_BankTransferSheet> createState() => _BankTransferSheetState();
}

class _BankTransferSheetState extends State<_BankTransferSheet> {
  String? _pickedFileName;
  String? _pickedFilePath;
  bool _uploading = false;
  String? _error;

  Future<void> _browseFile() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() {
      _pickedFilePath = file.path;
      _pickedFileName = file.name;
    });
  }

  Future<void> _submit() async {
    final path = _pickedFilePath;
    if (path == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await CryptoService.instance.uploadPaymentProof(
        reference: widget.order.reference,
        filePath: path,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = 'Could not upload proof. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final order = widget.order;
    final bank = widget.bank;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Buy Order',
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
            const Text(
              'Reference and amount for your buying order',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                  _OrderRow(label: 'Amount to pay:', value: _fmtNgn(order.totalNgn)),
                  const SizedBox(height: 12),
                  _OrderRow(
                    label: 'Reference',
                    value: order.reference,
                    valueStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (bank != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please make the payment to the account below:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Account Number: ${bank.accountNumber}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Account Name: ${bank.accountName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bank Name: ${bank.bankName}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Bank transfer details are not configured yet. Please contact support '
                  'with your reference to complete this payment.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9A5B13)),
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Upload Proof of Payment',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _pickedFileName ?? 'Upload proof of payment',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: _pickedFileName != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontWeight:
                            _pickedFileName != null ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: const Color(0xFFF0F1F5),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: _browseFile,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.attach_file_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Browse File',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'I Have Made The Payment',
              enabled: _pickedFilePath != null,
              loading: _uploading,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            _SecondaryButton(
              label: 'Cancel Transaction',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Transaction PIN sheet ───────────────────────────────────────────────────

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

// ─── Success sheet ───────────────────────────────────────────────────────────

class _PurchaseSuccessSheet extends StatelessWidget {
  const _PurchaseSuccessSheet({required this.onDone, required this.order, this.isSell = false});

  final VoidCallback onDone;
  final CryptoOrder order;
  final bool isSell;

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
          Text(
            isSell ? 'Sale Successful!' : 'Purchase Successful!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isSell
                ? '${_fmtNgn(order.totalNgn)} has been credited to your wallet.'
                : '${_fmtNum(order.coinAmount, decimals: order.coinAmount < 1 ? 6 : 2)} '
                    '${order.coin.toUpperCase()} has been credited to your wallet.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, height: 1.45, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          AuthPrimaryButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}

// ─── Shared form widgets ─────────────────────────────────────────────────────

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

class _BuySellTabs extends StatelessWidget {
  const _BuySellTabs({
    required this.buyMode,
    required this.onChanged,
    required this.onSwap,
    required this.onTransfer,
    required this.onDeposit,
  });

  final bool buyMode;
  final ValueChanged<bool> onChanged;
  final VoidCallback onSwap;
  final VoidCallback onTransfer;
  final VoidCallback onDeposit;

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
          Expanded(child: _TabChip(label: 'Buy', selected: buyMode, onTap: () => onChanged(true))),
          Expanded(
            child: _TabChip(label: 'Sell', selected: !buyMode, onTap: () => onChanged(false)),
          ),
          Expanded(child: _TabChip(label: 'Swap', selected: false, onTap: onSwap)),
          Expanded(child: _TabChip(label: 'Send', selected: false, onTap: onTransfer)),
          Expanded(child: _TabChip(label: 'Dep', selected: false, onTap: onDeposit)),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectTokenField extends StatelessWidget {
  const _SelectTokenField({required this.token, this.onTap});

  final CryptoCoin? token;
  final VoidCallback? onTap;

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(
            children: [
              if (has) ...[
                _CoinLogo(coin: token!, size: 24),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  has ? token!.symbol.toUpperCase() : 'Select Token',
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

class _QtyField extends StatelessWidget {
  const _QtyField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
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
        disabledBorder: OutlineInputBorder(
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E3A8A),
        ),
      ),
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

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

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
            style: valueStyle ??
                const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
          ),
        ),
      ],
    );
  }
}

class _TokenPickerSheet extends StatelessWidget {
  const _TokenPickerSheet({required this.tokens, required this.selected});

  final List<CryptoCoin> tokens;
  final CryptoCoin? selected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(8, 16, 8, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Token',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: tokens.length,
              itemBuilder: (context, index) {
                final t = tokens[index];
                final isSelected = selected?.symbol == t.symbol;
                return ListTile(
                  leading: _CoinLogo(coin: t, size: 36),
                  title: Text(
                    t.symbol.toUpperCase(),
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    t.name,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  trailing: Text(
                    t.rateNgn != null ? _fmtNgn(t.rateNgn!) : '—',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(t),
                );
              },
            ),
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

/// Real coin icon from the backend's CoinCap-CDN logo_url, falling back to
/// a color+letter circle if the image fails to load.
class _CoinLogo extends StatelessWidget {
  const _CoinLogo({required this.coin, this.size = 28});

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
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
