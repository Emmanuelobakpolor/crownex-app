import '../models/vtu.dart';
import 'api_client.dart';

/// Typed wrapper over /api/vtu/* (crownex-backend/vtu/urls.py).
class VtuService {
  VtuService._();

  static final VtuService instance = VtuService._();

  final ApiClient _client = ApiClient.instance;

  /// GET /vtu/catalogue/
  Future<VtuCatalogue> getCatalogue() async {
    final data = await _client.get('/vtu/catalogue/', auth: true);
    return VtuCatalogue.fromJson(data);
  }

  /// POST /vtu/airtime/
  Future<VtuTransaction> buyAirtime({
    required String subcategoryId,
    required String network,
    required String phone,
    required double amount,
    required String transactionPin,
  }) async {
    final data = await _client.post(
      '/vtu/airtime/',
      body: {
        'subcategory_id': subcategoryId,
        'network': network,
        'phone': phone,
        'amount': amount.toStringAsFixed(2),
        'transaction_pin': transactionPin,
      },
      auth: true,
    );
    return VtuTransaction.fromJson(data);
  }

  /// POST /vtu/data/
  Future<VtuTransaction> buyData({
    required String subcategoryId,
    required String network,
    required String planId,
    required String phone,
    required String transactionPin,
  }) async {
    final data = await _client.post(
      '/vtu/data/',
      body: {
        'subcategory_id': subcategoryId,
        'network': network,
        'plan_id': planId,
        'phone': phone,
        'transaction_pin': transactionPin,
      },
      auth: true,
    );
    return VtuTransaction.fromJson(data);
  }

  /// GET /vtu/cable/bouquets/?network=GOTV
  Future<List<BouquetOption>> getCableBouquets(String network) async {
    final data = await _client.get(
      '/vtu/cable/bouquets/?network=${Uri.encodeQueryComponent(network)}',
      auth: true,
    );
    final bouquets = data['bouquets'] as List<dynamic>? ?? const [];
    return bouquets
        .map((b) => BouquetOption.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  /// POST /vtu/cable/verify/ — returns whatever fields PluginNG sends back
  /// (undocumented shape); caller should look for a name-ish key.
  Future<Map<String, dynamic>> verifySmartcard({
    required String network,
    required String cardno,
  }) {
    return _client.post(
      '/vtu/cable/verify/',
      body: {'network': network, 'cardno': cardno},
      auth: true,
    );
  }

  /// POST /vtu/cable/
  Future<VtuTransaction> buyCable({
    required String subcategoryId,
    required String network,
    required String phone,
    required String cardno,
    required String variationCode,
    required String transactionPin,
  }) async {
    final data = await _client.post(
      '/vtu/cable/',
      body: {
        'subcategory_id': subcategoryId,
        'network': network,
        'phone': phone,
        'cardno': cardno,
        'variation_code': variationCode,
        'transaction_pin': transactionPin,
      },
      auth: true,
    );
    return VtuTransaction.fromJson(data);
  }

  /// GET /vtu/electricity/variations/?network=Eko-Electric
  Future<List<BouquetOption>> getElectricityVariations(String network) async {
    final data = await _client.get(
      '/vtu/electricity/variations/?network=${Uri.encodeQueryComponent(network)}',
      auth: true,
    );
    final variations = data['variations'] as List<dynamic>? ?? const [];
    return variations
        .map((v) => BouquetOption.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  /// POST /vtu/electricity/verify/ — same undocumented-shape caveat as
  /// verifySmartcard.
  Future<Map<String, dynamic>> verifyMeter({
    required String network,
    required String cardno,
    required String meterType,
  }) {
    return _client.post(
      '/vtu/electricity/verify/',
      body: {'network': network, 'cardno': cardno, 'meter_type': meterType},
      auth: true,
    );
  }

  /// POST /vtu/electricity/
  Future<VtuTransaction> buyElectricity({
    required String subcategoryId,
    required String network,
    required String serviceId,
    required String phone,
    required String cardno,
    required String variationCode,
    required double amount,
    required String transactionPin,
  }) async {
    final data = await _client.post(
      '/vtu/electricity/',
      body: {
        'subcategory_id': subcategoryId,
        'network': network,
        'service_id': serviceId,
        'phone': phone,
        'cardno': cardno,
        'variation_code': variationCode,
        'amount': amount.toStringAsFixed(2),
        'transaction_pin': transactionPin,
      },
      auth: true,
    );
    return VtuTransaction.fromJson(data);
  }

  /// GET `/vtu/transactions/<reference>/status/`
  Future<VtuTransaction> getStatus(String reference) async {
    final data = await _client.get(
      '/vtu/transactions/$reference/status/',
      auth: true,
    );
    return VtuTransaction.fromJson(data);
  }

  /// GET /vtu/transactions/ — latest 50, newest first.
  Future<List<VtuTransaction>> getTransactions() async {
    final data = await _client.getList('/vtu/transactions/', auth: true);
    return data
        .map((t) => VtuTransaction.fromJson(t as Map<String, dynamic>))
        .toList();
  }
}
