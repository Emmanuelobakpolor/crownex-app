import '../models/support.dart';
import 'api_client.dart';

/// Typed wrapper over /api/support/* (crownex-backend/support/urls.py).
class SupportService {
  SupportService._();

  static final SupportService instance = SupportService._();

  final ApiClient _client = ApiClient.instance;

  /// GET /support/conversation/ — the whole recent thread, or only messages
  /// newer than [afterId]. Also marks agent replies as read, so only call
  /// this while the chat screen is open.
  Future<SupportSnapshot> fetch({int? afterId}) async {
    final query = afterId != null ? '?after=$afterId' : '';
    final data = await _client.get('/support/conversation/$query', auth: true);
    return SupportSnapshot.fromJson(data);
  }

  /// POST /support/messages/
  Future<SupportMessage> send(String body) async {
    final data = await _client.post(
      '/support/messages/',
      body: {'body': body},
      auth: true,
    );
    return SupportMessage.fromJson(data);
  }

  /// POST /support/typing/ — the agent sees "typing…" for a few seconds
  /// after each ping.
  Future<void> setTyping(bool typing) async {
    await _client.post('/support/typing/', body: {'typing': typing}, auth: true);
  }

  /// GET /support/unread/ — agent replies not yet seen, for badges.
  Future<int> unreadCount() async {
    final data = await _client.get('/support/unread/', auth: true);
    return data['unread'] as int? ?? 0;
  }
}
