import 'crypto.dart';
import 'vtu.dart';
import 'wallet.dart';

/// Unifies wallet transactions (deposit/withdrawal), VTU purchases
/// (airtime/data) and on-chain crypto deposits into one shape so the home screen and transaction
/// history can show a single merged, chronologically-sorted feed.
enum AppTxCategory { deposit, withdrawal, airtime, data, cryptoDeposit }

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
