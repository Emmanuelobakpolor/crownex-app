import 'crypto.dart';
import 'giftcard.dart';
import 'vtu.dart';
import 'wallet.dart';

/// Unifies wallet transactions (deposit/withdrawal), VTU purchases
/// (airtime/data) and on-chain crypto deposits into one shape so the home screen and transaction
/// history can show a single merged, chronologically-sorted feed.
enum AppTxCategory {
  deposit,
  withdrawal,
  airtime,
  data,
  cryptoDeposit,
  cryptoBuy,
  cryptoSell,
  cryptoSwap,
  cryptoWithdrawal,
  giftCard,
}

enum AppTxStatus { pending, completed, failed }

/// One labelled line on the transaction details screen / shared receipt.
typedef TxDetail = ({String label, String value});

class AppTransaction {
  const AppTransaction({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isCredit,
    required this.status,
    required this.createdAt,
    this.amountLabel,
    this.reference = '',
    this.note = '',
    this.details = const [],
  });

  final String id;
  final AppTxCategory category;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final AppTxStatus status;
  final DateTime createdAt;

  /// Shown instead of the ₦ amount when the row isn't in naira — a crypto
  /// deposit that was kept as crypto, e.g. "+0.0025 BTC".
  final String? amountLabel;

  /// Our reference for the transaction — what support asks for.
  final String reference;

  /// Server-side note, e.g. why a withdrawal failed.
  final String note;

  /// Category-specific lines for the details screen (bank, phone, rate…),
  /// already formatted. Empty values are left out.
  final List<TxDetail> details;

  bool get isCrypto => switch (category) {
    AppTxCategory.cryptoDeposit ||
    AppTxCategory.cryptoBuy ||
    AppTxCategory.cryptoSell ||
    AppTxCategory.cryptoSwap ||
    AppTxCategory.cryptoWithdrawal => true,
    _ => false,
  };

  factory AppTransaction.fromWallet(WalletTransaction tx) {
    final isDeposit = tx.txType == TxType.deposit;
    return AppTransaction(
      id: tx.id,
      category: isDeposit ? AppTxCategory.deposit : AppTxCategory.withdrawal,
      title: isDeposit ? 'Deposit' : 'Withdrawal',
      subtitle: isDeposit
          ? tx.reference
          : (tx.bankName.isNotEmpty
                ? '${tx.bankName} • ${tx.accountNumber}'
                : tx.reference),
      amount: tx.amount,
      isCredit: isDeposit,
      status: switch (tx.status) {
        TxStatus.completed => AppTxStatus.completed,
        TxStatus.pending => AppTxStatus.pending,
        TxStatus.failed => AppTxStatus.failed,
      },
      createdAt: tx.createdAt,
      reference: tx.reference,
      note: tx.note,
      details: _nonEmpty(
        isDeposit
            ? [(label: 'Type', value: 'Wallet deposit')]
            : [
                (label: 'Type', value: 'Bank withdrawal'),
                (label: 'Recipient', value: tx.accountName),
                (label: 'Bank', value: tx.bankName),
                (label: 'Account number', value: tx.accountNumber),
              ],
      ),
    );
  }

  factory AppTransaction.fromVtu(VtuTransaction tx) {
    final isData = tx.service == 'data';
    return AppTransaction(
      id: tx.id,
      category: isData ? AppTxCategory.data : AppTxCategory.airtime,
      title: isData ? '${tx.network} Data' : '${tx.network} Airtime',
      subtitle: tx.phone,
      amount: tx.amount,
      isCredit: false,
      status: switch (tx.status) {
        VtuStatus.success => AppTxStatus.completed,
        VtuStatus.pending => AppTxStatus.pending,
        VtuStatus.failed => AppTxStatus.failed,
        VtuStatus.reversed => AppTxStatus.failed,
      },
      createdAt: tx.createdAt,
      reference: tx.reference,
      note: tx.note,
      details: _nonEmpty([
        (label: 'Type', value: isData ? 'Data purchase' : 'Airtime purchase'),
        (label: 'Network', value: tx.network),
        (label: 'Phone number', value: tx.phone),
        (label: 'Card / meter number', value: tx.cardNumber),
        if (tx.status == VtuStatus.reversed)
          (label: 'Refund', value: 'Reversed to wallet'),
      ]),
    );
  }

  factory AppTransaction.fromCryptoDeposit(CryptoDeposit d) {
    final coin = d.coin.toUpperCase();
    final coinAmount = '${formatCoinAmount(d.amount)} $coin';
    final converted =
        d.status == CryptoConversionStatus.converted && d.ngnAmount != null;
    return AppTransaction(
      id: 'crypto-deposit-${d.id}',
      category: AppTxCategory.cryptoDeposit,
      title: converted ? '$coin → NGN' : '$coin deposit',
      subtitle: switch (d.status) {
        CryptoConversionStatus.converted =>
          d.rateNgn != null
              ? '$coinAmount auto-converted at ₦${d.rateNgn!.toStringAsFixed(2)}'
              : '$coinAmount auto-converted',
        CryptoConversionStatus.converting => 'Converting $coinAmount to NGN…',
        CryptoConversionStatus.skipped =>
          'Kept as $coin (too small to convert)',
        CryptoConversionStatus.failed => 'Conversion failed — kept as $coin',
        CryptoConversionStatus.held => 'Held as $coin',
      },
      amount: converted ? d.ngnAmount! : 0,
      amountLabel: converted ? null : '+$coinAmount',
      isCredit: true,
      status: switch (d.status) {
        CryptoConversionStatus.converting => AppTxStatus.pending,
        CryptoConversionStatus.failed => AppTxStatus.failed,
        _ => AppTxStatus.completed,
      },
      createdAt: d.createdAt,
      reference: d.orderReference ?? '',
      details: _nonEmpty([
        (label: 'Type', value: 'Crypto deposit'),
        (label: 'Received', value: coinAmount),
        (
          label: 'Conversion',
          value: switch (d.status) {
            CryptoConversionStatus.converted => 'Converted to NGN',
            CryptoConversionStatus.converting => 'Converting to NGN',
            CryptoConversionStatus.skipped => 'Kept as $coin (too small)',
            CryptoConversionStatus.failed => 'Failed — kept as $coin',
            CryptoConversionStatus.held => 'Kept as $coin',
          },
        ),
        if (d.rateNgn != null)
          (label: 'Rate', value: '₦${d.rateNgn!.toStringAsFixed(2)} / $coin'),
      ]),
    );
  }

  /// Buy (NGN out), sell (NGN in) or coin-to-coin swap.
  factory AppTransaction.fromCryptoOrder(CryptoOrder o) {
    final coin = o.coin.toUpperCase();
    final toCoin = o.toCoin.toUpperCase();
    final coinAmount = '${formatCoinAmount(o.coinAmount)} $coin';
    final rate = '₦${o.rateNgn.toStringAsFixed(2)} / $coin';
    final status = switch (o.status) {
      CryptoOrderStatus.completed => AppTxStatus.completed,
      CryptoOrderStatus.failed => AppTxStatus.failed,
      _ => AppTxStatus.pending,
    };
    final progress = switch (o.status) {
      CryptoOrderStatus.pendingPayment => 'Awaiting payment',
      CryptoOrderStatus.paymentReceived => 'Payment received',
      CryptoOrderStatus.waitingDeposit => 'Waiting for deposit',
      CryptoOrderStatus.processing => 'Processing',
      CryptoOrderStatus.completed => '',
      CryptoOrderStatus.failed => '',
    };
    final fee = o.feeNgn > 0 ? '₦${o.feeNgn.toStringAsFixed(2)}' : '';
    final refund = o.refundedNgn != null
        ? '₦${o.refundedNgn!.toStringAsFixed(2)} to wallet'
        : '';

    switch (o.orderType) {
      case CryptoOrderType.buy:
        return AppTransaction(
          id: 'crypto-order-${o.id}',
          category: AppTxCategory.cryptoBuy,
          title: 'Buy $coin',
          subtitle: progress.isNotEmpty ? progress : '$coinAmount at $rate',
          amount: o.totalNgn,
          isCredit: false,
          status: status,
          createdAt: o.createdAt,
          reference: o.reference,
          note: o.note,
          details: _nonEmpty([
            (label: 'Type', value: 'Crypto purchase'),
            (label: 'Bought', value: coinAmount),
            (label: 'Rate', value: rate),
            (label: 'Fee', value: fee),
            (label: 'Progress', value: progress),
            (label: 'Refund', value: refund),
          ]),
        );
      case CryptoOrderType.sell:
        return AppTransaction(
          id: 'crypto-order-${o.id}',
          category: AppTxCategory.cryptoSell,
          title: 'Sell $coin',
          subtitle: progress.isNotEmpty ? progress : '$coinAmount at $rate',
          amount: o.totalNgn,
          isCredit: true,
          status: status,
          createdAt: o.createdAt,
          reference: o.reference,
          note: o.note,
          details: _nonEmpty([
            (label: 'Type', value: 'Crypto sale'),
            (label: 'Sold', value: coinAmount),
            (label: 'Rate', value: rate),
            (label: 'Fee', value: fee),
            (label: 'Progress', value: progress),
          ]),
        );
      case CryptoOrderType.swap:
        final received = o.toCoinAmount != null
            ? '${formatCoinAmount(o.toCoinAmount!)} $toCoin'
            : '';
        return AppTransaction(
          id: 'crypto-order-${o.id}',
          category: AppTxCategory.cryptoSwap,
          title: '$coin → $toCoin',
          subtitle: progress.isNotEmpty
              ? progress
              : (received.isNotEmpty ? 'Received $received' : 'Swap'),
          amount: 0,
          amountLabel: '-$coinAmount',
          isCredit: false,
          status: status,
          createdAt: o.createdAt,
          reference: o.reference,
          note: o.note,
          details: _nonEmpty([
            (label: 'Type', value: 'Crypto swap'),
            (label: 'Swapped', value: coinAmount),
            (label: 'Received', value: received),
            (label: 'Fee', value: fee),
            (label: 'Progress', value: progress),
            (label: 'Refund', value: refund),
          ]),
        );
    }
  }

  /// Reloadly gift card purchase, paid from the NGN wallet.
  factory AppTransaction.fromGiftCard(GiftCardPurchase p) {
    final usd = '\$${p.unitPriceUsd.toStringAsFixed(2)}';
    final name = p.productName.isNotEmpty ? p.productName : p.brand;
    return AppTransaction(
      id: 'giftcard-${p.id}',
      category: AppTxCategory.giftCard,
      title: '${p.brand} Gift Card',
      subtitle: switch (p.status) {
        GiftCardStatus.completed => '$usd • ${p.countryCode}',
        GiftCardStatus.pending => 'Processing $usd card…',
        GiftCardStatus.failed => 'Failed — refunded to wallet',
      },
      amount: p.amountNgn,
      isCredit: false,
      status: switch (p.status) {
        GiftCardStatus.completed => AppTxStatus.completed,
        GiftCardStatus.pending => AppTxStatus.pending,
        GiftCardStatus.failed => AppTxStatus.failed,
      },
      createdAt: p.createdAt,
      reference: p.reference,
      note: p.note,
      details: _nonEmpty([
        (label: 'Type', value: 'Gift card purchase'),
        (label: 'Card', value: name),
        (label: 'Value', value: '$usd (${p.countryCode})'),
        (label: 'Card number', value: p.redeemCode),
        (label: 'PIN', value: p.redeemPin),
        if (p.status == GiftCardStatus.failed)
          (label: 'Refund', value: 'Refunded to wallet'),
      ]),
    );
  }

  /// On-chain send to an external address.
  factory AppTransaction.fromCryptoWithdrawal(CryptoWithdrawal w) {
    final coin = w.coin.toUpperCase();
    final address = w.address.length > 14
        ? '${w.address.substring(0, 6)}…${w.address.substring(w.address.length - 6)}'
        : w.address;
    return AppTransaction(
      id: 'crypto-withdrawal-${w.id}',
      category: AppTxCategory.cryptoWithdrawal,
      title: 'Send $coin',
      subtitle: 'To $address',
      amount: 0,
      amountLabel: '-${formatCoinAmount(w.amount)} $coin',
      isCredit: false,
      status: switch (w.status) {
        CryptoWithdrawalStatus.completed => AppTxStatus.completed,
        CryptoWithdrawalStatus.processing => AppTxStatus.pending,
        CryptoWithdrawalStatus.failed ||
        CryptoWithdrawalStatus.rejected => AppTxStatus.failed,
      },
      createdAt: w.createdAt,
      reference: w.reference,
      note: w.note,
      details: _nonEmpty([
        (label: 'Type', value: 'Crypto withdrawal'),
        (label: 'Amount', value: '${formatCoinAmount(w.amount)} $coin'),
        (
          label: 'Network fee',
          value: w.feeCoin > 0 ? '${formatCoinAmount(w.feeCoin)} $coin' : '',
        ),
        (
          label: 'Recipient gets',
          value: '${formatCoinAmount(w.netAmount)} $coin',
        ),
        (label: 'Network', value: w.network.toUpperCase()),
        (label: 'Address', value: w.address),
        (label: 'Tx hash', value: w.txId),
        if (w.status == CryptoWithdrawalStatus.rejected)
          (label: 'Review', value: 'Rejected'),
      ]),
    );
  }
}

List<TxDetail> _nonEmpty(List<TxDetail> rows) => [
  for (final r in rows)
    if (r.value.trim().isNotEmpty) r,
];

/// Up to 8 decimals with trailing zeros trimmed: 0.00250000 -> "0.0025".
String formatCoinAmount(double v) {
  var s = v.toStringAsFixed(8);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}
