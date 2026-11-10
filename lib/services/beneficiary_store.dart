import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Which flow a saved beneficiary belongs to — each keeps its own list.
enum BeneficiaryKind { bank, airtime, data, crypto }

/// A recipient remembered after a successful transfer / purchase, so the
/// user can tap it to refill the form next time ("Send again").
class Beneficiary {
  const Beneficiary({
    required this.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.data = const {},
  });

  /// Uniqueness key within a kind, e.g. "058:0123456789" — re-saving the
  /// same recipient replaces the old entry and moves it to the top.
  final String key;
  final String title;
  final String subtitle;

  /// Shown on the right of the row (account number, etc).
  final String? trailing;

  /// Whatever the owning screen needs to refill its form.
  final Map<String, String> data;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        subtitle.toLowerCase().contains(q) ||
        (trailing?.toLowerCase().contains(q) ?? false);
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'title': title,
        'subtitle': subtitle,
        'trailing': trailing,
        'data': data,
      };

  factory Beneficiary.fromJson(Map<String, dynamic> json) {
    return Beneficiary(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      trailing: json['trailing'] as String?,
      data: (json['data'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
    );
  }
}

/// Saved beneficiaries, kept on-device per signed-in user so switching
/// accounts on the same phone never shows someone else's recipients.
class BeneficiaryStore {
  BeneficiaryStore._();

  static final BeneficiaryStore instance = BeneficiaryStore._();

  static const int _maxPerKind = 100;

  String _prefsKey(BeneficiaryKind kind, int? userId) =>
      'beneficiaries_${userId ?? 0}_${kind.name}';

  Future<List<Beneficiary>> load(BeneficiaryKind kind, int? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(kind, userId));
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => Beneficiary.fromJson(Map<String, dynamic>.from(m)))
          .where((b) => b.key.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(
    BeneficiaryKind kind,
    int? userId,
    List<Beneficiary> list,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey(kind, userId),
        jsonEncode(list.map((b) => b.toJson()).toList()),
      );
    } catch (_) {
      // Saving a beneficiary is a convenience — never fail the transfer over it.
    }
  }

  /// Adds (or refreshes) [beneficiary] at the top of the list.
  Future<List<Beneficiary>> save(
    BeneficiaryKind kind,
    int? userId,
    Beneficiary beneficiary,
  ) async {
    final list = await load(kind, userId);
    list.removeWhere((b) => b.key == beneficiary.key);
    list.insert(0, beneficiary);
    if (list.length > _maxPerKind) list.removeRange(_maxPerKind, list.length);
    await _write(kind, userId, list);
    return list;
  }

  Future<List<Beneficiary>> remove(
    BeneficiaryKind kind,
    int? userId,
    String key,
  ) async {
    final list = await load(kind, userId);
    list.removeWhere((b) => b.key == key);
    await _write(kind, userId, list);
    return list;
  }
}

/// Nigerian local format with the leading 0 — profiles and older records
/// sometimes hold "8031234567" or "2348031234567", which networks reject.
String toLocalPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('234') && digits.length == 13) {
    return '0${digits.substring(3)}';
  }
  if (digits.length == 10 && !digits.startsWith('0')) return '0$digits';
  return digits;
}
