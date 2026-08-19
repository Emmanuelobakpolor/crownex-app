/// Matches the payload returned by UserSerializer on the backend
/// (accounts/serializers.py) — login, complete-profile, PIN-set, and
/// profile endpoints all return this shape under a `user` key (or
/// directly, for GET /api/profile/).
class CrownexUser {
  const CrownexUser({
    required this.id,
    required this.email,
    required this.phone,
    required this.fullName,
    required this.profilePicture,
    required this.isVerified,
    required this.isProfileComplete,
    required this.hasTransactionPin,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String phone;
  final String fullName;
  final String? profilePicture;
  final bool isVerified;
  final bool isProfileComplete;
  final bool hasTransactionPin;
  final DateTime? createdAt;

  factory CrownexUser.fromJson(Map<String, dynamic> json) {
    return CrownexUser(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      profilePicture: json['profile_picture'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      isProfileComplete: json['is_profile_complete'] as bool? ?? false,
      hasTransactionPin: json['has_transaction_pin'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}
