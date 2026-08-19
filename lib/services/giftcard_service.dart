import '../models/giftcard.dart';
import 'api_client.dart';

/// Typed wrapper over /api/giftcards/* (crownex-backend/giftcards/urls.py).
class GiftCardService {
  GiftCardService._();

  static final GiftCardService instance = GiftCardService._();

  final ApiClient _client = ApiClient.instance;

  /// GET /giftcards/rate/
  Future<double> getRate() async {
    final data = await _client.get('/giftcards/rate/', auth: true);
    return double.tryParse(data['ngn_per_usd']?.toString() ?? '') ?? 0;
  }

  /// GET /giftcards/brands/?country_code=US
  Future<List<GiftCardBrand>> getBrands({required String countryCode}) async {
    final data = await _client.getList(
      '/giftcards/brands/?country_code=${Uri.encodeQueryComponent(countryCode)}',
      auth: true,
    );
    return data.map((b) => GiftCardBrand.fromJson(b as Map<String, dynamic>)).toList();
  }

  /// GET /giftcards/products/?brand=Apple&country_code=US
  Future<List<GiftCardProduct>> getProducts({
    required String brand,
    required String countryCode,
  }) async {
    final data = await _client.getList(
      '/giftcards/products/?brand=${Uri.encodeQueryComponent(brand)}'
      '&country_code=${Uri.encodeQueryComponent(countryCode)}',
      auth: true,
    );
    return data.map((p) => GiftCardProduct.fromJson(p as Map<String, dynamic>)).toList();
  }

  /// POST /giftcards/buy/
  Future<GiftCardPurchase> buy({
    required int productId,
    required double unitPriceUsd,
    required String brand,
    required String countryCode,
    required String transactionPin,
  }) async {
    final data = await _client.post(
      '/giftcards/buy/',
      body: {
        'product_id': productId,
        'unit_price_usd': unitPriceUsd.toStringAsFixed(2),
        'brand': brand,
        'country_code': countryCode,
        'pin': transactionPin,
      },
      auth: true,
    );
    return GiftCardPurchase.fromJson(data);
  }

  /// GET /giftcards/history/ — latest 50, newest first.
  Future<List<GiftCardPurchase>> getHistory() async {
    final data = await _client.getList('/giftcards/history/', auth: true);
    return data.map((p) => GiftCardPurchase.fromJson(p as Map<String, dynamic>)).toList();
  }
}
