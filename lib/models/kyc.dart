// Matches kyc/serializers.py (crownex-backend/kyc/urls.py) — identity
// verification status for virtual card eligibility.

double? _parseScore(dynamic v) => v == null ? null : double.tryParse(v.toString());

class KycVerification {
  const KycVerification({
    required this.idType,
    required this.idNumber,
    required this.fullName,
    required this.status,
    this.matchScore,
  });

  final String idType;
  final String idNumber;
  final String fullName;
  final String status; // pending | approved | rejected | review
  final double? matchScore;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPendingReview => status == 'pending' || status == 'review';

  factory KycVerification.fromJson(Map<String, dynamic> json) {
    return KycVerification(
      idType: json['id_type'] as String? ?? '',
      idNumber: json['id_number'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      matchScore: _parseScore(json['match_score']),
    );
  }
}
