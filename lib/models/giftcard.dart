// Matches giftcards/serializers.py — Reloadly-backed gift card catalogue and
// purchases (crownex-backend/giftcards/urls.py).

class GiftCardBrand {
  const GiftCardBrand({required this.brandId, required this.brandName, this.logoUrl});

  final int brandId;
  final String brandName;
  final String? logoUrl;

  factory GiftCardBrand.fromJson(Map<String, dynamic> json) {
    return GiftCardBrand(
      brandId: json['brand_id'] as int? ?? 0,
      brandName: json['brand_name'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
    );
  }
}

/// A single denomination (fixed) or the open USD range for a product.
class GiftCardProduct {
  const GiftCardProduct({
    required this.productId,
    required this.openRange,
    this.unitPriceUsd,
    this.unitPriceNgn,
    this.minUsd,
    this.maxUsd,
    this.redeemInstruction,
  });

  final int productId;
  final bool openRange;

  /// Set when [openRange] is false — a fixed denomination.
  final double? unitPriceUsd;
  final double? unitPriceNgn;

  /// Set when [openRange] is true.
  final double? minUsd;
  final double? maxUsd;

  final String? redeemInstruction;

  factory GiftCardProduct.fromJson(Map<String, dynamic> json) {
    double? parse(dynamic v) => v != null ? double.tryParse(v.toString()) : null;
    return GiftCardProduct(
      productId: json['product_id'] as int? ?? 0,
      openRange: json['open_range'] as bool? ?? false,
      unitPriceUsd: parse(json['unit_price_usd']),
      unitPriceNgn: parse(json['unit_price_ngn']),
      minUsd: parse(json['min_usd']),
      maxUsd: parse(json['max_usd']),
      redeemInstruction: json['redeem_instruction'] as String?,
    );
  }
}

enum GiftCardStatus { pending, completed, failed }

class GiftCardPurchase {
  const GiftCardPurchase({
    required this.id,
    required this.brand,
    required this.countryCode,
    required this.productId,
    required this.productName,
    required this.unitPriceUsd,
    required this.amountNgn,
    required this.reference,
    required this.status,
    required this.redeemCode,
    required this.redeemPin,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String brand;
  final String countryCode;
  final int productId;
  final String productName;
  final double unitPriceUsd;
  final double amountNgn;
  final String reference;
  final GiftCardStatus status;
  final String redeemCode;
  final String redeemPin;
  final String note;
  final DateTime createdAt;

  factory GiftCardPurchase.fromJson(Map<String, dynamic> json) {
    return GiftCardPurchase(
      id: json['id'] as String,
      brand: json['brand'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
      productId: json['product_id'] as int? ?? 0,
      productName: json['product_name'] as String? ?? '',
      unitPriceUsd: double.tryParse(json['unit_price_usd']?.toString() ?? '') ?? 0,
      amountNgn: double.tryParse(json['amount_ngn']?.toString() ?? '') ?? 0,
      reference: json['reference'] as String? ?? '',
      status: _statusFrom(json['status'] as String?),
      redeemCode: json['redeem_code'] as String? ?? '',
      redeemPin: json['redeem_pin'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  static GiftCardStatus _statusFrom(String? value) {
    switch (value) {
      case 'completed':
        return GiftCardStatus.completed;
      case 'failed':
        return GiftCardStatus.failed;
      default:
        return GiftCardStatus.pending;
    }
  }
}
