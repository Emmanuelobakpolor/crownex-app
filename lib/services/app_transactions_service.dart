import '../models/app_transaction.dart';
import '../models/crypto.dart';
import '../models/vtu.dart';
import '../models/wallet.dart';
import 'crypto_service.dart';
import 'vtu_service.dart';
import 'wallet_service.dart';

/// Merges /wallet/transactions/ (deposits/withdrawals), /vtu/transactions/
/// (airtime/data purchases) and /crypto/deposits/ (on-chain deposits and
/// their auto-convert outcome) into one chronologically-sorted feed.
class AppTransactionsService {
  AppTransactionsService._();

  static final AppTransactionsService instance = AppTransactionsService._();

  Future<List<AppTransaction>> getAll() async {
    final results = await Future.wait([
      WalletService.instance.getTransactions(),
      VtuService.instance.getTransactions(),
      // A crypto outage must not hide the naira history.
      CryptoService.instance
          .getDeposits()
          .catchError((_) => const <CryptoDeposit>[]),
    ]);
    final wallet = results[0] as List<WalletTransaction>;
    final vtu = results[1] as List<VtuTransaction>;
    final crypto = results[2] as List<CryptoDeposit>;

    final merged = [
      for (final tx in wallet) AppTransaction.fromWallet(tx),
      for (final tx in vtu) AppTransaction.fromVtu(tx),
      for (final d in crypto) AppTransaction.fromCryptoDeposit(d),
    ];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }
}
