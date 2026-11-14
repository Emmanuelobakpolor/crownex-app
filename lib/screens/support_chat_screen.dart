import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/support.dart';
import '../services/api_exception.dart';
import '../services/support_service.dart';
import '../services/user_session.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_widgets.dart';

/// Live chat with the Crownex admin team (crownex-backend/support).
///
/// There's no socket — the screen polls every [_pollEvery] while it's open
/// and in the foreground, fetching only messages newer than the last one it
/// has, plus whether an agent is typing.
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key, this.onClose});

  /// Set when the chat is shown inside the floating launcher panel
  /// (SupportChatLauncher) rather than as a pushed route: the header shows
  /// a minimise button that calls this instead of a back arrow.
  final VoidCallback? onClose;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

const _pollEvery = Duration(seconds: 2);

/// Re-ping "typing" at most this often while the user keeps typing — the
/// server treats a ping as live for 6s.
const _typingPingEvery = Duration(seconds: 3);

/// Tell the agent we've stopped after this long without a keystroke.
const _typingIdleAfter = Duration(seconds: 4);

const _quickTopics = <String>[
  'My deposit hasn’t arrived',
  'Withdrawal is delayed',
  'Crypto transfer issue',
  'Airtime or data failed',
  'Account & verification',
];

class _SupportChatScreenState extends State<SupportChatScreen>
    with WidgetsBindingObserver {
  final _service = SupportService.instance;
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();

  final List<SupportMessage> _messages = [];

  /// Bubble keys already on screen at first load — those render in place;
  /// anything after that animates in.
  final Set<String> _initialKeys = {};

  bool _loading = true;
  String? _loadError;
  bool _adminTyping = false;
  DateTime? _adminLastReadAt;
  bool _showJumpToLatest = false;

  Timer? _pollTimer;
  bool _polling = false;
  Timer? _typingIdleTimer;
  DateTime? _lastTypingPing;
  int _localSeq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _input.addListener(_onInputChanged);
    _scroll.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _typingIdleTimer?.cancel();
    if (_lastTypingPing != null) _sendTyping(false);
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _poll();
    } else if (state == AppLifecycleState.paused) {
      _pollTimer?.cancel();
    }
  }

  // ─── Data ──────────────────────────────────────────────────────────────────

  int? get _lastServerId {
    for (final m in _messages.reversed) {
      if (m.id > 0) return m.id;
    }
    return null;
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final snap = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(snap.messages);
        _initialKeys
          ..clear()
          ..addAll(_messages.map(_keyOf));
        _adminTyping = snap.adminTyping;
        _adminLastReadAt = snap.adminLastReadAt;
        _loading = false;
      });
      _startPolling();
    } on ApiException catch (e) {
      if (!mounted || e.isSessionExpired) return;
      setState(() {
        _loading = false;
        _loadError = e.message;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (_loading || _loadError != null) return;
    _pollTimer = Timer.periodic(_pollEvery, (_) => _poll());
  }

  Future<void> _poll() async {
    if (_polling || _loading || _loadError != null) return;
    _polling = true;
    try {
      final snap = await _service.fetch(afterId: _lastServerId);
      if (!mounted) return;
      final fresh = snap.messages
          .where((m) => !_messages.any((e) => e.id == m.id))
          .toList();
      final incoming = fresh.any((m) => !m.isMine);
      setState(() {
        _messages.addAll(fresh);
        _adminTyping = snap.adminTyping;
        _adminLastReadAt = snap.adminLastReadAt;
        if (incoming && _scroll.hasClients && _scroll.offset > 160) {
          _showJumpToLatest = true;
        }
      });
      if (incoming) HapticFeedback.lightImpact();
    } on ApiException {
      // Transient — the next tick retries.
    } finally {
      _polling = false;
    }
  }

  Future<void> _send([String? text]) async {
    final body = (text ?? _input.text).trim();
    if (body.isEmpty) return;
    HapticFeedback.selectionClick();

    final localId = 'local-${_localSeq++}';
    final pending = SupportMessage(
      id: -_localSeq,
      sender: SupportSender.user,
      senderName: '',
      body: body,
      createdAt: DateTime.now(),
      delivery: SupportDelivery.sending,
      localId: localId,
    );
    if (text == null) _input.clear();
    _typingIdleTimer?.cancel();
    _lastTypingPing = null; // the server clears typing on send

    setState(() {
      _messages.add(pending);
      _showJumpToLatest = false;
    });
    _scrollToLatest();
    await _deliver(pending);
  }

  Future<void> _deliver(SupportMessage pending) async {
    try {
      final saved = await _service.send(pending.body);
      if (!mounted) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.localId == pending.localId);
        // A poll may already have pulled the saved copy in.
        _messages.removeWhere((m) => m.id == saved.id);
        final replacement = saved.copyWith(localId: pending.localId);
        if (i >= 0 && i < _messages.length) {
          _messages[i] = replacement;
        } else {
          _messages.add(replacement);
        }
      });
    } on ApiException catch (e) {
      if (!mounted || e.isSessionExpired) return;
      setState(() {
        final i = _messages.indexWhere((m) => m.localId == pending.localId);
        if (i >= 0) {
          _messages[i] = pending.copyWith(delivery: SupportDelivery.failed);
        }
      });
    }
  }

  void _retry(SupportMessage failed) {
    setState(() {
      final i = _messages.indexWhere((m) => m.localId == failed.localId);
      if (i >= 0) {
        _messages[i] = failed.copyWith(delivery: SupportDelivery.sending);
      }
    });
    _deliver(failed);
  }

  // ─── Typing ────────────────────────────────────────────────────────────────

  void _onInputChanged() {
    setState(() {}); // send button state
    if (_input.text.trim().isEmpty) {
      _typingIdleTimer?.cancel();
      if (_lastTypingPing != null) {
        _lastTypingPing = null;
        _sendTyping(false);
      }
      return;
    }
    final now = DateTime.now();
    if (_lastTypingPing == null ||
        now.difference(_lastTypingPing!) >= _typingPingEvery) {
      _lastTypingPing = now;
      _sendTyping(true);
    }
    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(_typingIdleAfter, () {
      _lastTypingPing = null;
      _sendTyping(false);
    });
  }

  void _sendTyping(bool typing) {
    _service.setTyping(typing).catchError((_) {});
  }

  // ─── Scrolling ─────────────────────────────────────────────────────────────

  void _onScroll() {
    if (_showJumpToLatest && _scroll.offset < 80) {
      setState(() => _showJumpToLatest = false);
    }
  }

  void _scrollToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  static String _keyOf(SupportMessage m) => m.localId ?? 'm${m.id}';

  bool _isSeen(SupportMessage m) {
    final readAt = _adminLastReadAt;
    return m.isMine &&
        m.id > 0 &&
        readAt != null &&
        !m.createdAt.isAfter(readAt);
  }

  /// Newest-first rows for a reversed list: typing bubble, messages, and a
  /// date chip wherever the day changes.
  List<_Row> _rows() {
    final rows = <_Row>[];
    if (_adminTyping) rows.add(const _TypingRow());
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      final newer = i + 1 < _messages.length ? _messages[i + 1] : null;
      final older = i > 0 ? _messages[i - 1] : null;
      rows.add(
        _MessageRow(
          m,
          firstInGroup: older == null || !_sameGroup(older, m),
          lastInGroup: newer == null || !_sameGroup(m, newer),
        ),
      );
      if (older == null || !_sameDay(older.createdAt, m.createdAt)) {
        rows.add(_DateRow(m.createdAt));
      }
    }
    return rows;
  }

  static bool _sameGroup(SupportMessage a, SupportMessage b) =>
      a.sender == b.sender &&
      b.createdAt.difference(a.createdAt).inMinutes.abs() < 5 &&
      _sameDay(a.createdAt, b.createdAt);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserSession>().user;
    final firstName = (user?.fullName ?? '').trim().split(' ').first;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.statusBarStyle.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _ChatHeader(typing: _adminTyping, onClose: widget.onClose),
              Expanded(child: _buildBody(firstName)),
              _Composer(
                controller: _input,
                focusNode: _inputFocus,
                enabled: !_loading && _loadError == null,
                onSend: () => _send(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(String firstName) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    }
    if (_loadError != null) {
      return _ErrorState(message: _loadError!, onRetry: _loadInitial);
    }
    if (_messages.isEmpty && !_adminTyping) {
      return _WelcomeState(
        firstName: firstName,
        onTopic: (topic) {
          _input.text = '$topic — ';
          _input.selection = TextSelection.collapsed(
            offset: _input.text.length,
          );
          _inputFocus.requestFocus();
        },
      );
    }

    final rows = _rows();
    final maxBubble = MediaQuery.sizeOf(context).width * 0.76;

    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final row = rows[i];
            return switch (row) {
              _TypingRow() => const _TypingBubble(key: ValueKey('typing')),
              _DateRow(:final day) => _DateChip(
                key: ValueKey('d${day.year}-${day.month}-${day.day}'),
                day: day,
              ),
              _MessageRow(
                :final message,
                :final firstInGroup,
                :final lastInGroup,
              ) =>
                _AnimatedEntry(
                  key: ValueKey(_keyOf(message)),
                  animate: !_initialKeys.contains(_keyOf(message)),
                  fromRight: message.isMine,
                  child: _MessageBubble(
                    message: message,
                    maxWidth: maxBubble,
                    firstInGroup: firstInGroup,
                    lastInGroup: lastInGroup,
                    seen: _isSeen(message),
                    onRetry: message.delivery == SupportDelivery.failed
                        ? () => _retry(message)
                        : null,
                  ),
                ),
            };
          },
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSlide(
              offset: _showJumpToLatest ? Offset.zero : const Offset(0, 1.6),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _showJumpToLatest ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: _JumpPill(
                  onTap: () {
                    setState(() => _showJumpToLatest = false);
                    _scrollToLatest();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Row model ───────────────────────────────────────────────────────────────

sealed class _Row {
  const _Row();
}

class _TypingRow extends _Row {
  const _TypingRow();
}

class _DateRow extends _Row {
  const _DateRow(this.day);
  final DateTime day;
}

class _MessageRow extends _Row {
  const _MessageRow(
    this.message, {
    required this.firstInGroup,
    required this.lastInGroup,
  });
  final SupportMessage message;
  final bool firstInGroup;
  final bool lastInGroup;
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.typing, this.onClose});

  final bool typing;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (onClose == null) ...[
            const AuthBackButton(),
            const SizedBox(width: 12),
          ],
          const _AgentAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crownex Support',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previous, ?current],
                  ),
                  child: typing
                      ? Row(
                          key: const ValueKey('typing'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'typing',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: _BouncingDots(
                                dotSize: 3.6,
                                spacing: 2.4,
                                bounce: 2.6,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Online · usually replies in minutes',
                          key: const ValueKey('status'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                ),
              ],
            ),
          ),
          if (onClose != null) _MinimiseButton(onTap: onClose!),
        ],
      ),
    );
  }
}

/// Chevron that folds the floating chat panel back into its bubble.
class _MinimiseButton extends StatelessWidget {
  const _MinimiseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 24,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar({this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryGradientEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: size * 0.52,
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: _PulsingDot(borderColor: AppColors.surface),
          ),
        ],
      ),
    );
  }
}

/// Green "online" dot with a soft ripple.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.borderColor});

  final Color borderColor;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF22C55E);
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 1 + _c.value * 0.9,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: green.withValues(alpha: 0.45 * (1 - _c.value)),
                ),
              ),
            ),
            Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: green,
                border: Border.all(color: widget.borderColor, width: 2.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Messages ────────────────────────────────────────────────────────────────

/// Pops a new bubble in: slides up from its own side, scales and fades.
class _AnimatedEntry extends StatefulWidget {
  const _AnimatedEntry({
    super.key,
    required this.animate,
    required this.fromRight,
    required this.child,
  });

  final bool animate;
  final bool fromRight;
  final Widget child;

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.animate ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0, 0.6));
    return FadeTransition(
      opacity: fade,
      child: AnimatedBuilder(
        animation: curve,
        child: widget.child,
        builder: (_, child) {
          final t = curve.value;
          return Transform.translate(
            offset: Offset(0, (1 - t) * 18),
            child: Transform.scale(
              scale: 0.85 + 0.15 * t,
              alignment: widget.fromRight
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.maxWidth,
    required this.firstInGroup,
    required this.lastInGroup,
    required this.seen,
    this.onRetry,
  });

  final SupportMessage message;
  final double maxWidth;
  final bool firstInGroup;
  final bool lastInGroup;
  final bool seen;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;
    const r = Radius.circular(20);
    const tight = Radius.circular(6);
    // Corners on the sender's side tighten so a run of messages reads as
    // one stack, with the bottom one as the "tail".
    final radius = mine
        ? BorderRadius.only(
            topLeft: r,
            bottomLeft: r,
            topRight: firstInGroup ? r : tight,
            bottomRight: tight,
          )
        : BorderRadius.only(
            topRight: r,
            bottomRight: r,
            topLeft: firstInGroup ? r : tight,
            bottomLeft: tight,
          );

    final bubble = GestureDetector(
      onTap: onRetry,
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: message.body));
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message copied'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: message.delivery == SupportDelivery.sending ? 0.75 : 1,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            gradient: mine
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A6BFF), AppColors.primaryGradientEnd],
                  )
                : null,
            color: mine ? null : AppColors.surface,
            borderRadius: radius,
            border: mine ? null : Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: mine
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : Colors.black.withValues(
                        alpha: AppColors.isDark ? 0 : 0.04,
                      ),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            message.body,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.38,
              fontWeight: FontWeight.w500,
              color: mine ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: firstInGroup ? 10 : 2),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!mine && firstInGroup)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 4),
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[
                lastInGroup
                    ? const _AgentAvatar(size: 30)
                    : const SizedBox(width: 30),
                const SizedBox(width: 10),
              ],
              Flexible(child: bubble),
            ],
          ),
          if (lastInGroup || message.delivery != SupportDelivery.sent)
            Padding(
              padding: EdgeInsets.only(top: 4, left: mine ? 0 : 40, right: 2),
              child: _MetaLine(message: message, seen: seen),
            ),
        ],
      ),
    );
  }
}

/// Time plus, for the user's own messages, a delivery tick that morphs
/// sending → sent → seen.
class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.message, required this.seen});

  final SupportMessage message;
  final bool seen;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMuted;
    if (message.delivery == SupportDelivery.failed) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF4444)),
          SizedBox(width: 4),
          Text(
            'Not sent · tap to retry',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      );
    }

    final IconData icon;
    final Color iconColor;
    final String key;
    switch (message.delivery) {
      case SupportDelivery.sending:
        icon = Icons.schedule_rounded;
        iconColor = muted;
        key = 'sending';
      case _ when seen:
        icon = Icons.done_all_rounded;
        iconColor = AppColors.primary;
        key = 'seen';
      case _:
        icon = Icons.done_rounded;
        iconColor = muted;
        key = 'sent';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.createdAt),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: muted,
          ),
        ),
        if (message.isMine) ...[
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(icon, key: ValueKey(key), size: 15, color: iconColor),
          ),
          if (seen) ...[
            const SizedBox(width: 2),
            Text(
              'Seen',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ─── Typing indicator ────────────────────────────────────────────────────────

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return _AnimatedEntry(
      animate: true,
      fromRight: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const _AgentAvatar(size: 30),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: _BouncingDots(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots bouncing in a wave — the classic "typing…".
class _BouncingDots extends StatefulWidget {
  const _BouncingDots({
    required this.color,
    this.dotSize = 8,
    this.spacing = 5,
    this.bounce = 6,
  });

  final Color color;
  final double dotSize;
  final double spacing;
  final double bounce;

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.dotSize + widget.bounce,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            final phase = (_c.value - i * 0.16) % 1.0;
            final lift = phase < 0.5 ? math.sin(phase * 2 * math.pi) : 0.0;
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : widget.spacing),
              child: Transform.translate(
                offset: Offset(0, -widget.bounce * lift),
                child: Opacity(
                  opacity: 0.4 + 0.6 * lift,
                  child: Container(
                    width: widget.dotSize,
                    height: widget.dotSize,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Misc rows ───────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  const _DateChip({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            _formatDay(day),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _JumpPill extends StatelessWidget {
  const _JumpPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(22),
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'New message',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeState extends StatelessWidget {
  const _WelcomeState({required this.firstName, required this.onTopic});

  final String firstName;
  final ValueChanged<String> onTopic;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - t)),
            child: child,
          ),
        ),
        child: Column(
          children: [
            const _WavingAvatar(),
            const SizedBox(height: 20),
            Text(
              firstName.isNotEmpty ? 'Hi $firstName 👋' : 'Hi there 👋',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Our support team is here to help. Send us a message and '
              'we’ll reply right here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 26),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'What do you need help with?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final topic in _quickTopics)
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      onTap: () => onTopic(topic),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          topic,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Agent avatar that gently bobs, for the empty state.
class _WavingAvatar extends StatefulWidget {
  const _WavingAvatar();

  @override
  State<_WavingAvatar> createState() => _WavingAvatarState();
}

class _WavingAvatarState extends State<_WavingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: const _AgentAvatar(size: 76),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

// ─── Composer ────────────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final canSend = enabled && controller.text.trim().isNotEmpty;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.fieldFill,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message…',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _SendButton(enabled: canSend, onTap: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: enabled ? 1 : 0.88,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A6BFF), AppColors.primaryGradientEnd],
                  )
                : null,
            color: enabled ? null : AppColors.buttonDisabled,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: AnimatedRotation(
            turns: enabled ? 0 : -0.125,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Icon(
              Icons.send_rounded,
              size: 20,
              color: enabled ? Colors.white : AppColors.buttonDisabledText,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Formatting ──────────────────────────────────────────────────────────────

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String _formatTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _formatDay(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return _weekdays[d.weekday - 1];
  final base = '${d.day} ${_months[d.month - 1]}';
  return d.year == now.year ? base : '$base ${d.year}';
}
