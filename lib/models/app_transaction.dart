import 'vtu.dart';
import 'wallet.dart';

/// Unifies wallet transactions (deposit/withdrawal) and VTU purchases
/// (airtime/data) into one shape so the home screen and transaction
/// history can show a single merged, chronologically-sorted feed.
enum AppTxCategory { deposit, withdrawal, airtime, data }

enum AppTxStatus { pending, completed, failed }

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
  });

  final String id;
  final AppTxCategory category;
  final String title;
  final String subtitle;
  final double amount;
  final bool isCredit;
  final AppTxStatus status;
  final DateTime createdAt;

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
    );
  }
}
