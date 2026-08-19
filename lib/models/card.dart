// Matches cards/serializers.py (crownex-backend/cards/urls.py) — Bitnob
// virtual card status and transaction history.

DateTime _parseDate(dynamic v) => DateTime.tryParse(v as String? ?? '') ?? DateTime.now();

class VirtualCard {
  const VirtualCard({
    required this.status,
    required this.createdStatus,
    required this.cardBrand,
    required this.maskedPan,
    required this.cardholderName,
    required this.balanceDisplay,
  });

  final String status; // pending | active | frozen | terminated
  final String createdStatus; // processing | completed
  final String cardBrand;
  final String maskedPan;
  final String cardholderName;
  final String balanceDisplay; // USD, e.g. "5.00"

  bool get isActive => status == 'active';
  bool get isFrozen => status == 'frozen';
  bool get isProvisioning => status == 'pending' || createdStatus == 'processing';

  factory VirtualCard.fromJson(Map<String, dynamic> json) {
    return VirtualCard(
      status: json['status'] as String? ?? 'pending',
      createdStatus: json['created_status'] as String? ?? '',
      cardBrand: json['card_brand'] as String? ?? '',
      maskedPan: json['masked_pan'] as String? ?? '',
      cardholderName: json['cardholder_name'] as String? ?? '',
      balanceDisplay: json['balance_display'] as String? ?? '0.00',
    );
  }
}

class CardTransactionEntry {
  const CardTransactionEntry({
    required this.reference,
    required this.type,
    required this.status,
    required this.amountDisplay,
    required this.description,
    required this.createdAt,
  });

  final String reference;
  final String type; // funding | withdrawal
  final String status; // pending | completed | failed
  final String amountDisplay;
  final String description;
  final DateTime createdAt;

  bool get isFunding => type == 'funding';

  factory CardTransactionEntry.fromJson(Map<String, dynamic> json) {
    return CardTransactionEntry(
      reference: json['reference'] as String? ?? '',
      type: json['type'] as String? ?? 'funding',
      status: json['status'] as String? ?? 'pending',
      amountDisplay: json['amount_display'] as String? ?? '0.00',
      description: json['description'] as String? ?? '',
      createdAt: _parseDate(json['created_at']),
    );
  }
}
