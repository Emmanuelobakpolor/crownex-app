// Support chat payloads — crownex-backend/support/views.py.

enum SupportSender { user, admin }

/// Delivery state of a message the user sent. Agent messages are always
/// [sent].
enum SupportDelivery { sending, failed, sent }

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.sender,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.delivery = SupportDelivery.sent,
    this.localId,
  });

  /// Server id, or a negative placeholder while an optimistic send is in
  /// flight.
  final int id;
  final SupportSender sender;
  final String senderName;
  final String body;
  final DateTime createdAt;
  final SupportDelivery delivery;

  /// Stable key for an optimistic message, so its bubble keeps its
  /// animation state when the server copy replaces it.
  final String? localId;

  bool get isMine => sender == SupportSender.user;

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as int,
      sender: json['sender_type'] == 'admin'
          ? SupportSender.admin
          : SupportSender.user,
      senderName: json['sender_name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  SupportMessage copyWith({SupportDelivery? delivery, String? localId}) {
    return SupportMessage(
      id: id,
      sender: sender,
      senderName: senderName,
      body: body,
      createdAt: createdAt,
      delivery: delivery ?? this.delivery,
      localId: localId ?? this.localId,
    );
  }
}

/// One poll of the user's thread.
class SupportSnapshot {
  const SupportSnapshot({
    required this.messages,
    required this.adminTyping,
    required this.adminLastReadAt,
  });

  final List<SupportMessage> messages;
  final bool adminTyping;

  /// When an agent last opened the thread — user messages sent before this
  /// show as "Seen".
  final DateTime? adminLastReadAt;

  factory SupportSnapshot.fromJson(Map<String, dynamic> json) {
    return SupportSnapshot(
      messages: (json['messages'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SupportMessage.fromJson)
          .toList(),
      adminTyping: json['admin_typing'] as bool? ?? false,
      adminLastReadAt:
          DateTime.tryParse(json['admin_last_read_at'] as String? ?? '')
              ?.toLocal(),
    );
  }
}
