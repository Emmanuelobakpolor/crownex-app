import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/support_chat_screen.dart';
import '../services/support_service.dart';
import '../theme/app_colors.dart';

/// Floating live-chat bubble for the home shell.
///
/// Drag it anywhere and it springs to the nearest side edge. Tap it and the
/// chat unfolds out of the bubble as a panel while the bubble morphs into a
/// close button, so the same tap toggles it shut. While it's folded away it
/// polls the unread count and pulses when an agent has replied.
///
/// Place it over the tab content in a `Stack(fit: StackFit.expand)`; it only
/// takes taps on the bubble itself (and the scrim while open).
class SupportChatLauncher extends StatefulWidget {
  const SupportChatLauncher({super.key});

  @override
  State<SupportChatLauncher> createState() => SupportChatLauncherState();
}

const _bubbleSize = 58.0;
const _edge = 16.0;
const _unreadEvery = Duration(seconds: 20);

class SupportChatLauncherState extends State<SupportChatLauncher>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Where the bubble rests — kept for the app session so it doesn't jump back
  // when the home shell rebuilds.
  static bool _onRight = true;
  static double _fromBottom = 20;
  static bool _hintShown = false;

  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 280),
  )..addStatusListener((_) => setState(() {}));

  late final Animation<double> _openCurve = CurvedAnimation(
    parent: _open,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );

  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  Animation<Offset>? _snapTo;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final AnimationController _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  Size _area = Size.zero;
  Offset? _drag;
  bool _pressed = false;
  int _unread = 0;
  bool _hint = false;
  Timer? _unreadTimer;
  Timer? _hintTimer;

  bool get isOpen =>
      _open.status == AnimationStatus.forward ||
      _open.status == AnimationStatus.completed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshUnread();
    _startUnreadTimer();
    if (!_hintShown) {
      _hintShown = true;
      _hintTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted || isOpen) return;
        setState(() => _hint = true);
        _hintTimer = Timer(const Duration(seconds: 5), _hideHint);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    _hintTimer?.cancel();
    _open.dispose();
    _snap.dispose();
    _pulse.dispose();
    _wiggle.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!isOpen) {
        _refreshUnread();
        _startUnreadTimer();
      }
    } else if (state == AppLifecycleState.paused) {
      _unreadTimer?.cancel();
    }
  }

  // ── Toggle ────────────────────────────────────────────────────────────────

  void toggle() => isOpen ? close() : open();

  void open() {
    if (isOpen) return;
    HapticFeedback.lightImpact();
    _hideHint();
    _unreadTimer?.cancel();
    _setUnread(0);
    _open.forward();
  }

  void close() {
    if (!isOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _open.reverse().whenComplete(() {
      if (!mounted) return;
      _refreshUnread();
      _startUnreadTimer();
    });
  }

  void _hideHint() {
    _hintTimer?.cancel();
    if (_hint && mounted) setState(() => _hint = false);
  }

  // ── Unread badge ──────────────────────────────────────────────────────────

  void _startUnreadTimer() {
    _unreadTimer?.cancel();
    _unreadTimer = Timer.periodic(_unreadEvery, (_) => _refreshUnread());
  }

  Future<void> _refreshUnread() async {
    try {
      final n = await SupportService.instance.unreadCount();
      if (!mounted || isOpen) return;
      if (n > _unread) {
        HapticFeedback.selectionClick();
        _wiggle.forward(from: 0);
      }
      _setUnread(n);
    } catch (_) {
      // Badge is best-effort; the chat itself surfaces real errors.
    }
  }

  void _setUnread(int n) {
    if (n == _unread) return;
    setState(() => _unread = n);
    if (n > 0) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  // ── Dragging ──────────────────────────────────────────────────────────────

  Offset _restPos(Size s) {
    final maxFromBottom = math.max(_edge, s.height - _bubbleSize - _edge);
    final fromBottom = _fromBottom.clamp(_edge, maxFromBottom);
    final x = _onRight ? s.width - _bubbleSize - _edge : _edge;
    return Offset(x, s.height - _bubbleSize - fromBottom);
  }

  Offset _dockPos(Size s) => Offset(
    _onRight ? s.width - _bubbleSize - _edge : _edge,
    s.height - _bubbleSize - _edge,
  );

  Offset _currentRest() =>
      _snap.isAnimating && _snapTo != null ? _snapTo!.value : _restPos(_area);

  void _onDragStart(DragStartDetails d) {
    if (isOpen) return;
    _hideHint();
    _snap.stop();
    setState(() {
      _drag = _currentRest();
      _pressed = false;
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_drag == null) return;
    final next = _drag! + d.delta;
    setState(() {
      _drag = Offset(
        next.dx.clamp(0, _area.width - _bubbleSize),
        next.dy.clamp(0, _area.height - _bubbleSize),
      );
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final from = _drag;
    if (from == null) return;
    final vx = d.velocity.pixelsPerSecond.dx;
    final centreX = from.dx + _bubbleSize / 2;
    _onRight = vx.abs() > 700 ? vx > 0 : centreX > _area.width / 2;
    _fromBottom = _area.height - _bubbleSize - from.dy;
    final to = _restPos(_area);
    _snapTo = Tween(
      begin: from,
      end: to,
    ).animate(CurvedAnimation(parent: _snap, curve: Curves.elasticOut));
    HapticFeedback.selectionClick();
    setState(() => _drag = null);
    _snap.forward(from: 0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _area = constraints.biggest;
          // The Scaffold strips view insets from its body, so ask the view.
          final keyboardUp = View.of(context).viewInsets.bottom > 0;
          return AnimatedBuilder(
            animation: Listenable.merge([_open, _snap]),
            builder: (context, _) => _buildLayers(keyboardUp),
          );
        },
      ),
    );
  }

  Widget _buildLayers(bool keyboardUp) {
    final t = _open.value;
    final eased = Curves.easeOutCubic.transform(t);
    final rest = _drag ?? _currentRest();
    final dock = _dockPos(_area);
    final pos = Offset.lerp(rest, dock, eased)!;
    final showPanel = _open.status != AnimationStatus.dismissed;
    final hideBubble = keyboardUp && isOpen;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (showPanel)
          Positioned.fill(
            child: GestureDetector(
              onTap: close,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.32 * t),
              ),
            ),
          ),
        if (showPanel)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: 10,
            right: 10,
            top: 10,
            bottom: hideBubble ? 10 : _bubbleSize + _edge + 12,
            child: _Panel(
              progress: _openCurve.value,
              opacity: (t * 1.8).clamp(0.0, 1.0),
              alignment: _onRight
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              onClose: close,
            ),
          ),
        _buildHint(rest),
        Positioned(
          left: pos.dx,
          top: pos.dy,
          child: AnimatedScale(
            scale: hideBubble ? 0 : (_pressed ? 0.9 : 1),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: toggle,
              onPanStart: _onDragStart,
              onPanUpdate: _onDragUpdate,
              onPanEnd: _onDragEnd,
              child: _Bubble(
                openness: t,
                unread: _unread,
                dragging: _drag != null,
                pulse: _pulse,
                wiggle: _wiggle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// "Chat with us" pill that slides out beside the bubble once per session.
  Widget _buildHint(Offset rest) {
    final visible = _hint && !isOpen && _drag == null;
    final top = rest.dy + (_bubbleSize - 40) / 2;
    final pill = IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        child: AnimatedSlide(
          offset: visible ? Offset.zero : Offset(_onRight ? 0.25 : -0.25, 0),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          child: GestureDetector(
            onTap: open,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Text(
                'Need help? Chat with us 👋',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return _onRight
        ? Positioned(top: top, right: _area.width - rest.dx + 10, child: pill)
        : Positioned(top: top, left: rest.dx + _bubbleSize + 10, child: pill);
  }
}

// ─── Panel ───────────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({
    required this.progress,
    required this.opacity,
    required this.alignment,
    required this.onClose,
  });

  /// 0 folded into the bubble → 1 open (overshoots slightly on the way in).
  final double progress;
  final double opacity;
  final Alignment alignment;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: lerpDouble(0.3, 1, progress)!,
        alignment: alignment,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: RepaintBoundary(
              // The panel positions itself, so the chat shouldn't pad for
              // the status bar or home indicator again.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: SupportChatScreen(onClose: onClose),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bubble ──────────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.openness,
    required this.unread,
    required this.dragging,
    required this.pulse,
    required this.wiggle,
  });

  /// 0 = chat icon, 1 = close icon.
  final double openness;
  final int unread;
  final bool dragging;
  final Animation<double> pulse;
  final Animation<double> wiggle;

  @override
  Widget build(BuildContext context) {
    final t = openness.clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, wiggle]),
      builder: (context, _) {
        final w = wiggle.value;
        final shake = w == 0 ? 0.0 : math.sin(w * math.pi * 6) * (1 - w) * 0.32;
        return Transform.rotate(
          angle: shake,
          child: SizedBox(
            width: _bubbleSize,
            height: _bubbleSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (unread > 0 && t == 0) _ring(pulse.value),
                if (unread > 0 && t == 0) _ring((pulse.value + 0.5) % 1),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _bubbleSize,
                  height: _bubbleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryGradientEnd],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(
                          alpha: dragging ? 0.5 : 0.38,
                        ),
                        blurRadius: dragging ? 26 : 18,
                        offset: Offset(0, dragging ? 10 : 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: 1 - t,
                        child: Transform.rotate(
                          angle: -t * math.pi / 2,
                          child: Transform.scale(
                            scale: 1 - t * 0.5,
                            child: const Icon(
                              Icons.chat_bubble_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                      Opacity(
                        opacity: t,
                        child: Transform.rotate(
                          angle: (1 - t) * math.pi / 2,
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Opacity(
                      opacity: 1 - t,
                      child: _Badge(count: unread),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _ring(double v) {
    return IgnorePointer(
      child: Transform.scale(
        scale: 1 + v * 0.7,
        child: Container(
          width: _bubbleSize,
          height: _bubbleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: (1 - v) * 0.28),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // Keyed on the count so each new reply pops the badge again.
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 0.3, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        constraints: const BoxConstraints(minWidth: 22),
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    );
  }
}
