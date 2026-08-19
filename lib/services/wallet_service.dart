import '../models/wallet.dart';
import 'api_client.dart';

/// Typed wrapper over /api/wallet/* (crownex-backend/wallet/urls.py).
class WalletService {
  WalletService._();

  static final WalletService instance = WalletService._();

  final ApiClient _client = ApiClient.instance;

  /// GET /wallet/balance/
  Future<WalletBalance> getWallet() async {
    final data = await _client.get('/wallet/balance/', auth: true);
    return WalletBalance.fromJson(data);
  }

  /// POST /wallet/initiate-deposit/
  Future<DepositInit> initiateDeposit({
    required double amount,
    required String txRef,
  }) async {
    final data = await _client.post(
      '/wallet/initiate-deposit/',
      body: {'amount': amount.toStringAsFixed(2), 'tx_ref': txRef},
      auth: true,
    );
    return DepositInit.fromJson(data);
  }

  /// POST /wallet/verify-payment/ — returns the freshly credited balance.
  Future<double> verifyPayment(String txRef) async {
    final data = await _client.post(
      '/wallet/verify-payment/',
      body: {'tx_ref': txRef},
      auth: true,
    );
    return double.tryParse(data['ngn_balance']?.toString() ?? '') ?? 0;
  }

  /// GET /wallet/banks/
  Future<List<Bank>> getBanks() async {
    final data = await _client.get('/wallet/banks/', auth: true);
    final banks = data['banks'] as List<dynamic>? ?? const [];
    return banks
        .map((b) => Bank.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  /// GET /wallet/resolve-account/?account_number=&bank_code=
  Future<String> resolveAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    final data = await _client.get(
      '/wallet/resolve-account/?account_number=$accountNumber&bank_code=$bankCode',
      auth: true,
    );
    return data['account_name'] as String? ?? '';
  }

  /// POST /wallet/withdraw/ — returns the Flutterwave-side reference.
  Future<String> requestWithdrawal({
    required double amount,
    required String accountName,
    required String bankName,
    required String bankCode,
    required String accountNumber,
  }) async {
    final data = await _client.post(
      '/wallet/withdraw/',
      body: {
        'amount': amount.toStringAsFixed(2),
        'account_name': accountName,
        'bank_name': bankName,
        'bank_code': bankCode,
        'account_number': accountNumber,
      },
      auth: true,
    );
    return data['reference'] as String;
  }

  /// GET /wallet/transactions/ — latest 50, newest first.
  Future<List<WalletTransaction>> getTransactions() async {
    final data = await _client.getList('/wallet/transactions/', auth: true);
    return data
        .map((t) => WalletTransaction.fromJson(t as Map<String, dynamic>))
        .toList();
  }
}
