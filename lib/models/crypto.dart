// Matches crypto/serializers.py (crownex-backend/crypto/urls.py) — live
// prices, wallets, quotes, orders, deposit addresses, deposits, and
// withdrawals.

import 'dart:ui' show Color;

double? _parseNullable(dynamic v) => v == null ? null : double.tryParse(v.toString());
double _parse(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
DateTime _parseDate(dynamic v) =>
    DateTime.tryParse(v as String? ?? '') ?? DateTime.now();

/// Coins that require picking a network, and which ones — keep in sync with
/// crypto/withdrawals.py:_ADDRESS_PATTERNS. The full coin list itself is
/// never hardcoded here — GET /crypto/prices/ is the source of truth.
const Map<String, List<String>> kCryptoCoinNetworks = {
  'usdt': ['TRC20', 'ERC20', 'BEP20'],
  'usdc': ['ERC20', 'BEP20', 'POLYGON'],
};

class CryptoCoin {
  const CryptoCoin({
    required this.symbol,
    required this.name,
    this.rateNgn,
    required this.logoUrl,
    required this.color,
    required this.letter,
  });

  final String symbol;
  final String name;

  /// Null when Quidax's live price for this market is temporarily unavailable.
  final double? rateNgn;

  /// CoinCap CDN icon URL — not from Quidax. Fall back to [color]+[letter]
  /// if the image fails to load (network hiccup, icon missing, etc).
  final String logoUrl;
  final String color;
  final String letter;

  factory CryptoCoin.fromJson(Map<String, dynamic> json) {
    return CryptoCoin(
      symbol: json['symbol'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rateNgn: _parseNullable(json['rate_ngn']),
      logoUrl: json['logo_url'] as String? ?? '',
      color: json['color'] as String? ?? '#0052FF',
      letter: json['letter'] as String? ?? '?',
    );
  }
}

/// Parses a '#RRGGBB' string into a Color, falling back to CrownEx blue.
Color colorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return const Color(0xFF0052FF);
  return Color(0xFF000000 | value);
}

class CryptoWalletBalance {
  const CryptoWalletBalance({
    required this.coin,
    required this.name,
    required this.available,
    required this.reserved,
    required this.total,
  });

  final String coin;
  final String name;
  final double available;
  final double reserved;
  final double total;

  factory CryptoWalletBalance.fromJson(Map<String, dynamic> json) {
    return CryptoWalletBalance(
      coin: json['coin'] as String? ?? '',
      name: json['name'] as String? ?? '',
      available: _parse(json['available']),
      reserved: _parse(json['reserved']),
      total: _parse(json['total']),
    );
  }
}

enum CryptoQuoteType { buy, sell, swap }

CryptoQuoteType _quoteTypeFrom(String? v) {
  switch (v) {
    case 'sell':
      return CryptoQuoteType.sell;
    case 'swap':
      return CryptoQuoteType.swap;
    default:
      return CryptoQuoteType.buy;
  }
}

class CryptoQuote {
  const CryptoQuote({
    required this.id,
    required this.quoteType,
    required this.coin,
    required this.toCoin,
    required this.coinAmount,
    required this.rateNgn,
    this.toRateNgn,
    required this.feeNgn,
    required this.totalNgn,
    this.toCoinAmount,
    required this.expiresAt,
    required this.expiresIn,
  });

  final String id;
  final CryptoQuoteType quoteType;
  final String coin;
  final String toCoin;
  final double coinAmount;
  final double rateNgn;
  final double? toRateNgn;
  final double feeNgn;
  final double totalNgn;
  final double? toCoinAmount;
  final DateTime expiresAt;
  final int expiresIn;

  factory CryptoQuote.fromJson(Map<String, dynamic> json) {
    return CryptoQuote(
      id: json['id'] as String? ?? '',
      quoteType: _quoteTypeFrom(json['quote_type'] as String?),
      coin: json['coin'] as String? ?? '',
      toCoin: json['to_coin'] as String? ?? '',
      coinAmount: _parse(json['coin_amount']),
      rateNgn: _parse(json['rate_ngn']),
      toRateNgn: _parseNullable(json['to_rate_ngn']),
      feeNgn: _parse(json['fee_ngn']),
      totalNgn: _parse(json['total_ngn']),
      toCoinAmount: _parseNullable(json['to_coin_amount']),
      expiresAt: _parseDate(json['expires_at']),
      expiresIn: json['expires_in'] as int? ?? 0,
    );
  }
}

enum CryptoOrderType { buy, sell, swap }

CryptoOrderType _orderTypeFrom(String? v) {
  switch (v) {
    case 'sell':
      return CryptoOrderType.sell;
    case 'swap':
      return CryptoOrderType.swap;
    default:
      return CryptoOrderType.buy;
  }
}

enum CryptoOrderStatus {
  pendingPayment,
  paymentReceived,
  waitingDeposit,
  processing,
  completed,
  failed,
}

CryptoOrderStatus _orderStatusFrom(String? v) {
  switch (v) {
    case 'payment_received':
      return CryptoOrderStatus.paymentReceived;
    case 'waiting_deposit':
      return CryptoOrderStatus.waitingDeposit;
    case 'processing':
      return CryptoOrderStatus.processing;
    case 'completed':
      return CryptoOrderStatus.completed;
    case 'failed':
      return CryptoOrderStatus.failed;
    default:
      return CryptoOrderStatus.pendingPayment;
  }
}

class CryptoOrder {
  const CryptoOrder({
    required this.id,
    required this.reference,
    required this.orderType,
    required this.coin,
    required this.toCoin,
    required this.coinAmount,
    this.toCoinAmount,
    required this.rateNgn,
    this.toRateNgn,
    required this.feeNgn,
    required this.totalNgn,
    required this.status,
    this.paymentProof,
    required this.note,
    this.refundedNgn,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String reference;
  final CryptoOrderType orderType;
  final String coin;
  final String toCoin;
  final double coinAmount;
  final double? toCoinAmount;
  final double rateNgn;
  final double? toRateNgn;
  final double feeNgn;
  final double totalNgn;
  final CryptoOrderStatus status;
  final String? paymentProof;
  final String note;

  /// Swap only: NGN credited to the user's wallet because the destination
  /// coin couldn't be bought. Non-null means "refunded", not "lost".
  final double? refundedNgn;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CryptoOrder.fromJson(Map<String, dynamic> json) {
    return CryptoOrder(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      orderType: _orderTypeFrom(json['order_type'] as String?),
      coin: json['coin'] as String? ?? '',
      toCoin: json['to_coin'] as String? ?? '',
      coinAmount: _parse(json['coin_amount']),
      toCoinAmount: _parseNullable(json['to_coin_amount']),
      rateNgn: _parse(json['rate_ngn']),
      toRateNgn: _parseNullable(json['to_rate_ngn']),
      feeNgn: _parse(json['fee_ngn']),
      totalNgn: _parse(json['total_ngn']),
      status: _orderStatusFrom(json['status'] as String?),
      paymentProof: json['payment_proof'] as String?,
      note: json['note'] as String? ?? '',
      refundedNgn: _parseNullable(json['refunded_ngn']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

/// POST /crypto/orders/buy/ response — the order plus (when still owed
/// money) how to pay: Flutterwave checkout details or a bank account.
class CryptoBuyResult {
  const CryptoBuyResult({
    required this.order,
    required this.needsPayment,
    this.paymentMethod,
    this.flutterwave,
    this.bankDetails,
  });

  final CryptoOrder order;
  final bool needsPayment;
  final String? paymentMethod; // 'flutterwave' | 'bank_transfer'
  final FlutterwaveInit? flutterwave;
  final CryptoBankDetails? bankDetails;

  factory CryptoBuyResult.fromJson(Map<String, dynamic> json) {
    final flw = json['flutterwave'] as Map<String, dynamic>?;
    final bank = json['bank_details'] as Map<String, dynamic>?;
    return CryptoBuyResult(
      order: CryptoOrder.fromJson(json),
      needsPayment: json['needs_payment'] as bool? ?? false,
      paymentMethod: json['payment_method'] as String?,
      flutterwave: flw != null ? FlutterwaveInit.fromJson(flw) : null,
      bankDetails: bank != null ? CryptoBankDetails.fromJson(bank) : null,
    );
  }
}

class FlutterwaveInit {
  const FlutterwaveInit({
    required this.publicKey,
    required this.txRef,
    required this.amount,
    required this.customerEmail,
    required this.customerPhone,
    required this.customerName,
  });

  final String publicKey;
  final String txRef;
  final double amount;
  final String customerEmail;
  final String customerPhone;
  final String customerName;

  factory FlutterwaveInit.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? const {};
    return FlutterwaveInit(
      publicKey: json['public_key'] as String? ?? '',
      txRef: json['tx_ref'] as String? ?? '',
      amount: _parse(json['amount']),
      customerEmail: customer['email'] as String? ?? '',
      customerPhone: customer['phone'] as String? ?? '',
      customerName: customer['name'] as String? ?? '',
    );
  }
}

class CryptoBankDetails {
  const CryptoBankDetails({
    required this.accountName,
    required this.accountNumber,
    required this.bankName,
  });

  final String accountName;
  final String accountNumber;
  final String bankName;

  factory CryptoBankDetails.fromJson(Map<String, dynamic> json) {
    return CryptoBankDetails(
      accountName: json['account_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
    );
  }
}

/// POST /crypto/orders/sell/ response — the order plus whether it's
/// parked waiting for a deposit (insufficient balance).
class CryptoSellResult {
  const CryptoSellResult({required this.order, required this.waitingDeposit});

  final CryptoOrder order;
  final bool waitingDeposit;

  factory CryptoSellResult.fromJson(Map<String, dynamic> json) {
    return CryptoSellResult(
      order: CryptoOrder.fromJson(json),
      waitingDeposit: json['waiting_deposit'] as bool? ?? false,
    );
  }
}

class CryptoDepositAddress {
  const CryptoDepositAddress({
    required this.coin,
    required this.network,
    required this.address,
    required this.createdAt,
  });

  final String coin;
  final String network;
  final String address;
  final DateTime createdAt;

  factory CryptoDepositAddress.fromJson(Map<String, dynamic> json) {
    return CryptoDepositAddress(
      coin: json['coin'] as String? ?? '',
      network: json['network'] as String? ?? '',
      address: json['address'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
    );
  }
}

enum CryptoWithdrawalStatus { processing, completed, failed, rejected }

CryptoWithdrawalStatus _withdrawalStatusFrom(String? v) {
  switch (v) {
    case 'completed':
      return CryptoWithdrawalStatus.completed;
    case 'failed':
      return CryptoWithdrawalStatus.failed;
    case 'rejected':
      return CryptoWithdrawalStatus.rejected;
    default:
      return CryptoWithdrawalStatus.processing;
  }
}

class CryptoWithdrawal {
  const CryptoWithdrawal({
    required this.id,
    required this.reference,
    required this.coin,
    required this.network,
    required this.address,
    required this.amount,
    required this.feeCoin,
    required this.netAmount,
    required this.status,
    required this.txId,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String reference;
  final String coin;
  final String network;
  final String address;
  final double amount;
  final double feeCoin;
  final double netAmount;
  final CryptoWithdrawalStatus status;
  final String txId;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CryptoWithdrawal.fromJson(Map<String, dynamic> json) {
    return CryptoWithdrawal(
      id: json['id'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      coin: json['coin'] as String? ?? '',
      network: json['network'] as String? ?? '',
      address: json['address'] as String? ?? '',
      amount: _parse(json['amount']),
      feeCoin: _parse(json['fee_coin']),
      netAmount: _parse(json['net_amount']),
      status: _withdrawalStatusFrom(json['status'] as String?),
      txId: json['tx_id'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

/// What happened to a deposit (crypto/serializers.py:CryptoDepositSerializer):
/// held as crypto (auto-convert off), or the auto-convert outcome.
enum CryptoConversionStatus { held, converting, converted, skipped, failed }

CryptoConversionStatus _conversionStatusFrom(String? value) {
  switch (value) {
    case 'converting':
      return CryptoConversionStatus.converting;
    case 'converted':
      return CryptoConversionStatus.converted;
    case 'skipped':
      return CryptoConversionStatus.skipped;
    case 'failed':
      return CryptoConversionStatus.failed;
    default:
      return CryptoConversionStatus.held;
  }
}

/// GET /crypto/deposits/ — one credited on-chain deposit; ngnAmount/rateNgn
/// are set only once auto-convert has sold it.
class CryptoDeposit {
  const CryptoDeposit({
    required this.id,
    required this.coin,
    required this.amount,
    required this.autoConvert,
    required this.status,
    required this.ngnAmount,
    required this.rateNgn,
    required this.orderReference,
    required this.createdAt,
  });

  final String id;
  final String coin;
  final double amount;
  final bool autoConvert;
  final CryptoConversionStatus status;
  final double? ngnAmount;
  final double? rateNgn;
  final String? orderReference;
  final DateTime createdAt;

  factory CryptoDeposit.fromJson(Map<String, dynamic> json) {
    return CryptoDeposit(
      id: json['id']?.toString() ?? '',
      coin: json['coin'] as String? ?? '',
      amount: _parse(json['amount']),
      autoConvert: json['auto_convert'] as bool? ?? false,
      status: _conversionStatusFrom(json['conversion_status'] as String?),
      ngnAmount: _parseNullable(json['ngn_amount']),
      rateNgn: _parseNullable(json['rate_ngn']),
      orderReference: json['order_reference'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }
}

/// GET /crypto/withdraw/estimate/ — read-only fee/net preview shown before
/// the user confirms (withdrawals have no locked quote like buy/sell/swap).
class WithdrawEstimate {
  const WithdrawEstimate({
    required this.coin,
    required this.amount,
    required this.rateNgn,
    required this.notionalNgn,
    required this.feeCoin,
    required this.feeNgn,
    required this.netAmount,
  });

  final String coin;
  final double amount;
  final double rateNgn;
  final double notionalNgn;
  final double feeCoin;
  final double feeNgn;
  final double netAmount;

  factory WithdrawEstimate.fromJson(Map<String, dynamic> json) {
    return WithdrawEstimate(
      coin: json['coin'] as String? ?? '',
      amount: _parse(json['amount']),
      rateNgn: _parse(json['rate_ngn']),
      notionalNgn: _parse(json['notional_ngn']),
      feeCoin: _parse(json['fee_coin']),
      feeNgn: _parse(json['fee_ngn']),
      netAmount: _parse(json['net_amount']),
    );
  }
}

/// One chain a coin can be sent on — [code] goes back to the backend as-is.
class WithdrawNetwork {
  const WithdrawNetwork({required this.code, required this.label});

  final String code;
  final String label;

  factory WithdrawNetwork.fromJson(Map<String, dynamic> json) {
    final code = json['code'] as String? ?? '';
    return WithdrawNetwork(code: code, label: json['label'] as String? ?? code);
  }
}

/// A withdrawable coin with the user's balance and what they can send now.
/// Rate-derived fields are null while Quidax has no live price for the coin.
class WithdrawCoinOption {
  const WithdrawCoinOption({
    required this.coin,
    required this.networks,
    required this.available,
    this.availableNgn,
    this.availableUsd,
    this.rateUsd,
    this.minAmount,
    this.maxAmount,
    this.maxAmountRaw,
  });

  final CryptoCoin coin;
  final List<WithdrawNetwork> networks;
  final double available;
  final double? availableNgn;
  final double? availableUsd;
  final double? rateUsd;
  final double? minAmount;
  final double? maxAmount;

  /// The backend's exact max, for filling the amount field without float noise.
  final String? maxAmountRaw;

  String get symbol => coin.symbol;
  double? get rateNgn => coin.rateNgn;

  factory WithdrawCoinOption.fromJson(Map<String, dynamic> json) {
    final symbol = json['coin'] as String? ?? '';
    return WithdrawCoinOption(
      coin: CryptoCoin(
        symbol: symbol,
        name: json['name'] as String? ?? symbol.toUpperCase(),
        rateNgn: _parseNullable(json['rate_ngn']),
        logoUrl: json['logo_url'] as String? ?? '',
        color: json['color'] as String? ?? '#0052FF',
        letter: json['letter'] as String? ?? '?',
      ),
      networks: ((json['networks'] as List?) ?? const [])
          .map((n) => WithdrawNetwork.fromJson(n as Map<String, dynamic>))
          .toList(),
      available: _parse(json['available']),
      availableNgn: _parseNullable(json['available_ngn']),
      availableUsd: _parseNullable(json['available_usd']),
      rateUsd: _parseNullable(json['rate_usd']),
      minAmount: _parseNullable(json['min_amount']),
      maxAmount: _parseNullable(json['max_amount']),
      maxAmountRaw: json['max_amount'] as String?,
    );
  }
}

/// GET /crypto/withdraw/options/ — what the send screen offers.
class WithdrawOptions {
  const WithdrawOptions({
    required this.usdRateNgn,
    required this.dailyLimitNgn,
    required this.dailyRemainingNgn,
    required this.coins,
  });

  final double usdRateNgn;
  final double dailyLimitNgn;
  final double dailyRemainingNgn;
  final List<WithdrawCoinOption> coins;

  factory WithdrawOptions.fromJson(Map<String, dynamic> json) {
    return WithdrawOptions(
      usdRateNgn: _parse(json['usd_rate_ngn']),
      dailyLimitNgn: _parse(json['daily_limit_ngn']),
      dailyRemainingNgn: _parse(json['daily_remaining_ngn']),
      coins: ((json['coins'] as List?) ?? const [])
          .map((c) => WithdrawCoinOption.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
