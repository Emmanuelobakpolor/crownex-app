// Matches wallet/serializers.py — the NGN wallet balance, transaction
// history rows, and the Flutterwave checkout payload for a deposit.

class WalletBalance {
  const WalletBalance({required this.ngnBalance});

  final double ngnBalance;

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    return WalletBalance(
      ngnBalance: double.tryParse(json['ngn_balance']?.toString() ?? '') ?? 0,
    );
  }
}

class DepositInit {
  const DepositInit({
    required this.txRef,
    required this.amount,
    required this.publicKey,
    required this.customerEmail,
    required this.customerPhone,
    required this.customerName,
  });

  final String txRef;
  final double amount;
  final String publicKey;
  final String customerEmail;
  final String customerPhone;
  final String customerName;

  factory DepositInit.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>? ?? const {};
    return DepositInit(
      txRef: json['tx_ref'] as String,
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      publicKey: json['public_key'] as String? ?? '',
      customerEmail: customer['email'] as String? ?? '',
      customerPhone: customer['phone'] as String? ?? '',
      customerName: customer['name'] as String? ?? '',
    );
  }
}

class Bank {
  const Bank({required this.name, required this.code});

  final String name;
  final String code;

  factory Bank.fromJson(Map<String, dynamic> json) {
    return Bank(
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
    );
  }
}

enum TxType { deposit, withdrawal }

enum TxStatus { pending, completed, failed }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.txType,
    required this.amount,
    required this.status,
    required this.reference,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final TxType txType;
  final double amount;
  final TxStatus status;
  final String reference;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String note;
  final DateTime createdAt;

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      txType: (json['tx_type'] as String?) == 'withdrawal'
          ? TxType.withdrawal
          : TxType.deposit,
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      status: _statusFrom(json['status'] as String?),
      reference: json['reference'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static TxStatus _statusFrom(String? value) {
    switch (value) {
      case 'completed':
        return TxStatus.completed;
      case 'failed':
        return TxStatus.failed;
      default:
        return TxStatus.pending;
    }
  }
}
