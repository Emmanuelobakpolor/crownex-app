import '../models/app_transaction.dart';
import '../models/vtu.dart';
import '../models/wallet.dart';
import 'vtu_service.dart';
import 'wallet_service.dart';

/// Merges /wallet/transactions/ (deposits/withdrawals) and /vtu/transactions/
/// (airtime/data purchases) into one chronologically-sorted feed.
class AppTransactionsService {
  AppTransactionsService._();

  static final AppTransactionsService instance = AppTransactionsService._();

  Future<List<AppTransaction>> getAll() async {
    final results = await Future.wait([
      WalletService.instance.getTransactions(),
      VtuService.instance.getTransactions(),
    ]);
    final wallet = results[0] as List<WalletTransaction>;
    final vtu = results[1] as List<VtuTransaction>;

    final merged = [
      for (final tx in wallet) AppTransaction.fromWallet(tx),
      for (final tx in vtu) AppTransaction.fromVtu(tx),
    ];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }
}
