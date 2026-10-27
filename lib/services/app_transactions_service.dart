import '../models/app_transaction.dart';
import '../models/crypto.dart';
import '../models/giftcard.dart';
import '../models/vtu.dart';
import '../models/wallet.dart';
import 'crypto_service.dart';
import 'giftcard_service.dart';
import 'vtu_service.dart';
import 'wallet_service.dart';

/// Merges /wallet/transactions/ (deposits/withdrawals), /vtu/transactions/
/// (airtime/data purchases), /crypto/deposits/ (on-chain deposits and
/// their auto-convert outcome), /crypto/orders/ (buy/sell/swap) and
/// /crypto/withdrawals/ (on-chain sends) and /giftcards/history/ (gift
/// card purchases) into one chronologically-sorted feed.
class AppTransactionsService {
  AppTransactionsService._();

  static final AppTransactionsService instance = AppTransactionsService._();

  Future<List<AppTransaction>> getAll() async {
    final crypto = CryptoService.instance;
    final results = await Future.wait([
      WalletService.instance.getTransactions(),
      VtuService.instance.getTransactions(),
      // A crypto outage must not hide the naira history.
      crypto.getDeposits().catchError((_) => const <CryptoDeposit>[]),
      crypto.getOrderHistory().catchError((_) => const <CryptoOrder>[]),
      crypto.getWithdrawalHistory().catchError(
        (_) => const <CryptoWithdrawal>[],
      ),
      GiftCardService.instance.getHistory().catchError(
        (_) => const <GiftCardPurchase>[],
      ),
    ]);
    final wallet = results[0] as List<WalletTransaction>;
    final vtu = results[1] as List<VtuTransaction>;
    final deposits = results[2] as List<CryptoDeposit>;
    final orders = results[3] as List<CryptoOrder>;
    final sends = results[4] as List<CryptoWithdrawal>;
    final giftCards = results[5] as List<GiftCardPurchase>;

    // An auto-converted deposit already shows as one "USDT → NGN" row; the
    // sell order behind it would be the same money twice.
    final autoConvertRefs = {
      for (final d in deposits)
        if (d.orderReference != null) d.orderReference!,
    };

    final merged = [
      for (final tx in wallet) AppTransaction.fromWallet(tx),
      for (final tx in vtu) AppTransaction.fromVtu(tx),
      for (final d in deposits) AppTransaction.fromCryptoDeposit(d),
      for (final o in orders)
        if (!autoConvertRefs.contains(o.reference))
          AppTransaction.fromCryptoOrder(o),
      for (final w in sends) AppTransaction.fromCryptoWithdrawal(w),
      for (final g in giftCards) AppTransaction.fromGiftCard(g),
    ];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }
}
