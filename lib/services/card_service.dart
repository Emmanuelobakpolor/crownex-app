import '../models/card.dart';
import 'api_client.dart';

/// Typed wrapper over /api/cards/* (crownex-backend/cards/urls.py).
class CardService {
  CardService._();

  static final CardService instance = CardService._();

  final ApiClient _client = ApiClient.instance;

  /// POST /cards/request/ — KYC- and PIN-gated. Async: card comes back
  /// pending, poll [getStatus] for the final state.
  Future<VirtualCard> requestCard({required String pin, String address = ''}) async {
    final data = await _client.post(
      '/cards/request/',
      body: {'pin': pin, if (address.isNotEmpty) 'address': address},
      auth: true,
    );
    return VirtualCard.fromJson(data);
  }

  /// GET /cards/status/ — null if no card has been requested yet.
  Future<VirtualCard?> getStatus() async {
    final data = await _client.get('/cards/status/', auth: true);
    if (data['status'] == null) return null;
    return VirtualCard.fromJson(data);
  }

  Future<CardTransactionEntry> fundCard({required double ngnAmount, required String pin}) async {
    final data = await _client.post(
      '/cards/fund/',
      body: {'ngn_amount': ngnAmount.toString(), 'pin': pin},
      auth: true,
    );
    return CardTransactionEntry.fromJson(data);
  }

  Future<CardTransactionEntry> withdrawCard({required double ngnAmount, required String pin}) async {
    final data = await _client.post(
      '/cards/withdraw/',
      body: {'ngn_amount': ngnAmount.toString(), 'pin': pin},
      auth: true,
    );
    return CardTransactionEntry.fromJson(data);
  }

  Future<VirtualCard> freezeCard() async {
    final data = await _client.post('/cards/freeze/', auth: true);
    return VirtualCard.fromJson(data);
  }

  Future<VirtualCard> unfreezeCard() async {
    final data = await _client.post('/cards/unfreeze/', auth: true);
    return VirtualCard.fromJson(data);
  }

  Future<VirtualCard> terminateCard({required String reason, required String pin}) async {
    final data = await _client.post(
      '/cards/terminate/',
      body: {'reason': reason, 'pin': pin},
      auth: true,
    );
    return VirtualCard.fromJson(data);
  }

  Future<List<CardTransactionEntry>> getTransactions() async {
    final data = await _client.getList('/cards/transactions/', auth: true);
    return data.map((t) => CardTransactionEntry.fromJson(t as Map<String, dynamic>)).toList();
  }
}
