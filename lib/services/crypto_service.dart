import 'dart:math';

import '../models/crypto.dart';
import 'api_client.dart';

/// Typed wrapper over /api/crypto/* (crownex-backend/crypto/urls.py).
class CryptoService {
  CryptoService._();

  static final CryptoService instance = CryptoService._();

  final ApiClient _client = ApiClient.instance;
  final Random _random = Random.secure();

  /// A fresh idempotency key for a new buy/sell/swap/withdraw request — the
  /// server returns the same result if this exact request is retried.
  String generateIdempotencyKey() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final suffix = (_random.nextInt(900000) + 100000).toString();
    return 'CRX-$millis-$suffix';
  }

  /// GET /crypto/prices/
  Future<List<CryptoCoin>> getPrices() async {
    final data = await _client.get('/crypto/prices/');
    final coins = data['coins'] as List<dynamic>? ?? const [];
    return coins.map((c) => CryptoCoin.fromJson(c as Map<String, dynamic>)).toList();
  }

  /// POST /crypto/account/ensure/ — best-effort Quidax sub-account warm-up.
  /// Fire-and-forget: never throws, so callers can call this without
  /// awaiting or wrapping it in try/catch. Meant to be called the instant
  /// a user opens the crypto section, so the account is usually already
  /// provisioned by the time they request a deposit address.
  Future<void> ensureAccount() async {
    try {
      await _client.post('/crypto/account/ensure/', auth: true);
    } catch (_) {
      // Best-effort — the lazy fallback on the deposit-address endpoint
      // covers this if it fails here.
    }
  }

  /// GET /crypto/wallets/
  Future<List<CryptoWalletBalance>> getWallets() async {
    final data = await _client.getList('/crypto/wallets/', auth: true);
    return data
        .map((w) => CryptoWalletBalance.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  /// POST /crypto/quote/
  Future<CryptoQuote> createQuote({
    required String type,
    required String coin,
    required double amount,
    String? toCoin,
  }) async {
    final data = await _client.post(
      '/crypto/quote/',
      body: {
        'type': type,
        'coin': coin,
        'amount': amount.toString(),
        if (toCoin != null) 'to_coin': toCoin,
      },
      auth: true,
    );
    return CryptoQuote.fromJson(data);
  }

  /// POST /crypto/orders/buy/
  Future<CryptoBuyResult> placeBuyOrder({
    required String quoteId,
    required String pin,
    String? idempotencyKey,
  }) async {
    final data = await _client.post(
      '/crypto/orders/buy/',
      body: {
        'quote_id': quoteId,
        'pin': pin,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
      auth: true,
    );
    return CryptoBuyResult.fromJson(data);
  }

  /// POST /crypto/orders/buy/verify/ — after a Flutterwave checkout.
  Future<CryptoOrder> verifyBuyPayment(String reference) async {
    final data = await _client.post(
      '/crypto/orders/buy/verify/',
      body: {'reference': reference},
      auth: true,
    );
    return CryptoOrder.fromJson(data);
  }

  /// POST /crypto/orders/<reference>/proof/ — bank-transfer buy proof.
  Future<CryptoOrder> uploadPaymentProof({
    required String reference,
    required String filePath,
  }) async {
    final data = await _client.postMultipart(
      '/crypto/orders/$reference/proof/',
      fileField: 'proof',
      filePath: filePath,
      auth: true,
    );
    return CryptoOrder.fromJson(data);
  }

  /// POST /crypto/orders/sell/
  Future<CryptoSellResult> placeSellOrder({
    required String quoteId,
    required String pin,
    String? idempotencyKey,
  }) async {
    final data = await _client.post(
      '/crypto/orders/sell/',
      body: {
        'quote_id': quoteId,
        'pin': pin,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
      auth: true,
    );
    return CryptoSellResult.fromJson(data);
  }

  /// POST /crypto/orders/sell/<reference>/retry/
  Future<CryptoOrder> retrySellAfterDeposit(String reference) async {
    final data = await _client.post(
      '/crypto/orders/sell/$reference/retry/',
      auth: true,
    );
    return CryptoOrder.fromJson(data);
  }

  /// POST /crypto/orders/swap/
  Future<CryptoOrder> placeSwapOrder({
    required String quoteId,
    required String pin,
    String? idempotencyKey,
  }) async {
    final data = await _client.post(
      '/crypto/orders/swap/',
      body: {
        'quote_id': quoteId,
        'pin': pin,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
      auth: true,
    );
    return CryptoOrder.fromJson(data);
  }

  /// GET /crypto/orders/ — latest 50, newest first.
  Future<List<CryptoOrder>> getOrderHistory() async {
    final data = await _client.getList('/crypto/orders/', auth: true);
    return data.map((o) => CryptoOrder.fromJson(o as Map<String, dynamic>)).toList();
  }

  /// GET /crypto/address/<coin>/?network=
  Future<CryptoDepositAddress> getDepositAddress(String coin, {String? network}) async {
    final query = network != null && network.isNotEmpty
        ? '?network=${Uri.encodeQueryComponent(network)}'
        : '';
    final data = await _client.get('/crypto/address/$coin/$query', auth: true);
    return CryptoDepositAddress.fromJson(data);
  }

  /// GET /crypto/withdraw/estimate/?coin=&amount= — no side effects.
  Future<WithdrawEstimate> estimateWithdrawal({
    required String coin,
    required double amount,
  }) async {
    final data = await _client.get(
      '/crypto/withdraw/estimate/?coin=${Uri.encodeQueryComponent(coin)}'
      '&amount=${Uri.encodeQueryComponent(amount.toString())}',
      auth: true,
    );
    return WithdrawEstimate.fromJson(data);
  }

  /// POST /crypto/withdraw/
  Future<CryptoWithdrawal> requestWithdrawal({
    required String coin,
    required double amount,
    required String address,
    required String pin,
    String? network,
    String? idempotencyKey,
  }) async {
    final data = await _client.post(
      '/crypto/withdraw/',
      body: {
        'coin': coin,
        'amount': amount.toString(),
        'address': address,
        'pin': pin,
        if (network != null) 'network': network,
        if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      },
      auth: true,
    );
    return CryptoWithdrawal.fromJson(data);
  }

  /// GET /crypto/withdrawals/ — latest 50, newest first.
  Future<List<CryptoWithdrawal>> getWithdrawalHistory() async {
    final data = await _client.getList('/crypto/withdrawals/', auth: true);
    return data
        .map((w) => CryptoWithdrawal.fromJson(w as Map<String, dynamic>))
        .toList();
  }
}
