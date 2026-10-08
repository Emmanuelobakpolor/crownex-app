import '../models/kyc.dart';
import 'api_client.dart';

/// Typed wrapper over /api/kyc/* (crownex-backend/kyc/urls.py).
class KycService {
  KycService._();

  static final KycService instance = KycService._();

  final ApiClient _client = ApiClient.instance;

  /// POST /kyc/submit/ — multipart. Calls Dojah synchronously server-side;
  /// the returned status may be approved/rejected (auto-decided by match
  /// score) or review (sitting in the admin queue).
  Future<KycVerification> submitVerification({
    required String idType,
    required String idNumber,
    required String selfiePath,
    String? idDocumentPath,
    String address = '',
  }) async {
    final data = await _client.postMultipart(
      '/kyc/submit/',
      fields: {
        'id_type': idType,
        'id_number': idNumber,
        if (address.isNotEmpty) 'address': address,
      },
      fileField: 'selfie',
      filePath: selfiePath,
      extraFiles: idDocumentPath != null ? {'id_document': idDocumentPath} : null,
      auth: true,
    );
    return KycVerification.fromJson(data);
  }

  /// GET /kyc/status/ — null if the user has never submitted.
  Future<KycVerification?> getStatus() async {
    final data = await _client.get('/kyc/status/', auth: true);
    if (data['status'] == null) return null;
    return KycVerification.fromJson(data);
  }

  /// PATCH /kyc/address/ — saves the residential address collected in the
  /// wizard's last step. Separate from submitVerification so it doesn't
  /// re-trigger a Dojah call; requires a prior submission to exist.
  Future<KycVerification> updateAddress(String address) async {
    final data = await _client.patch(
      '/kyc/address/',
      body: {'address': address},
      auth: true,
    );
    return KycVerification.fromJson(data);
  }
}
