// Matches vtu/serializers.py — PluginNG-backed airtime/data catalogue and
// purchase transactions (crownex-backend/vtu/urls.py).

class VtuNetwork {
  const VtuNetwork({required this.subcategoryId, required this.name});

  final String subcategoryId;
  final String name;

  factory VtuNetwork.fromJson(Map<String, dynamic> json) {
    return VtuNetwork(
      subcategoryId: json['subcategory_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class DataPlan {
  const DataPlan({required this.planId, required this.amount});

  /// PluginNG's plan label (e.g. "500MB for 30 days") — also the value we
  /// send back as plan_id when purchasing.
  final String planId;
  final double amount;

  factory DataPlan.fromJson(Map<String, dynamic> json) {
    return DataPlan(
      planId: json['plan'] as String? ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
    );
  }
}

class DataNetwork {
  const DataNetwork({
    required this.subcategoryId,
    required this.name,
    required this.plans,
  });

  final String subcategoryId;
  final String name;
  final List<DataPlan> plans;

  factory DataNetwork.fromJson(Map<String, dynamic> json) {
    final plans = (json['plans'] as List<dynamic>? ?? const [])
        .map((p) => DataPlan.fromJson(p as Map<String, dynamic>))
        .toList();
    return DataNetwork(
      subcategoryId: json['subcategory_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      plans: plans,
    );
  }
}

class ElectricityBiller {
  const ElectricityBiller({
    required this.subcategoryId,
    required this.name,
    required this.serviceId,
  });

  final String subcategoryId;
  final String name;

  /// PluginNG's exact `serviceID` string (e.g. "EKEDC - Eko Electric") —
  /// distinct from [name] and required by the purchase call.
  final String serviceId;

  factory ElectricityBiller.fromJson(Map<String, dynamic> json) {
    return ElectricityBiller(
      subcategoryId: json['subcategory_id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      serviceId: json['service_id'] as String? ?? '',
    );
  }
}

/// A cable bouquet or electricity variation type, from GET /fetch/bouquet.
class BouquetOption {
  const BouquetOption({required this.variationCode, required this.name, this.amount});

  final String variationCode;
  final String name;

  /// Cable bouquets have a fixed price; electricity variation types (e.g.
  /// Prepaid/Postpaid) don't — amount is chosen freely at purchase time.
  final double? amount;

  factory BouquetOption.fromJson(Map<String, dynamic> json) {
    return BouquetOption(
      variationCode: json['variation_code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      amount: json['amount'] != null
          ? double.tryParse(json['amount'].toString())
          : null,
    );
  }
}

class VtuCatalogue {
  const VtuCatalogue({
    required this.airtime,
    required this.data,
    required this.cable,
    required this.electricity,
  });

  final List<VtuNetwork> airtime;
  final List<DataNetwork> data;
  final List<VtuNetwork> cable;
  final List<ElectricityBiller> electricity;

  factory VtuCatalogue.fromJson(Map<String, dynamic> json) {
    final airtime = (json['airtime'] as List<dynamic>? ?? const [])
        .map((n) => VtuNetwork.fromJson(n as Map<String, dynamic>))
        .toList();
    final data = (json['data'] as List<dynamic>? ?? const [])
        .map((n) => DataNetwork.fromJson(n as Map<String, dynamic>))
        .toList();
    final cable = (json['cable'] as List<dynamic>? ?? const [])
        .map((n) => VtuNetwork.fromJson(n as Map<String, dynamic>))
        .toList();
    final electricity = (json['electricity'] as List<dynamic>? ?? const [])
        .map((n) => ElectricityBiller.fromJson(n as Map<String, dynamic>))
        .toList();
    return VtuCatalogue(
      airtime: airtime,
      data: data,
      cable: cable,
      electricity: electricity,
    );
  }
}

enum VtuStatus { pending, success, failed, reversed }

class VtuTransaction {
  const VtuTransaction({
    required this.id,
    required this.service,
    required this.network,
    required this.planId,
    required this.phone,
    required this.cardNumber,
    required this.amount,
    required this.status,
    required this.reference,
    required this.providerResponse,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String service; // 'airtime' | 'data' | 'cable' | 'electricity'
  final String network;
  final String planId;
  final String phone;
  final String cardNumber;
  final double amount;
  final VtuStatus status;
  final String reference;
  final String providerResponse;
  final String note;
  final DateTime createdAt;

  factory VtuTransaction.fromJson(Map<String, dynamic> json) {
    return VtuTransaction(
      id: json['id'] as String,
      service: json['service'] as String? ?? '',
      network: json['network'] as String? ?? '',
      planId: json['plan_id'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      cardNumber: json['card_number'] as String? ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      status: _statusFrom(json['status'] as String?),
      reference: json['reference'] as String? ?? '',
      providerResponse: json['provider_response'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static VtuStatus _statusFrom(String? value) {
    switch (value) {
      case 'success':
        return VtuStatus.success;
      case 'failed':
        return VtuStatus.failed;
      case 'reversed':
        return VtuStatus.reversed;
      default:
        return VtuStatus.pending;
    }
  }
}
