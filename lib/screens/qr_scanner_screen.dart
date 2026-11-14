import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/crypto_qr.dart';
import '../theme/app_colors.dart';

/// Full-screen camera that reads a wallet / exchange deposit QR code and pops
/// with the [CryptoQrPayload] in it. Codes that aren't an address (website
/// links, plain text) are rejected in place and scanning carries on. Users
/// can also pick a screenshot of a QR code from their gallery.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  /// Opens the scanner; null when the user backs out.
  static Future<CryptoQrPayload?> open(BuildContext context) {
    return Navigator.of(context).push<CryptoQrPayload>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => const QrScannerScreen(),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

const _success = Color(0xFF22C55E);
const _danger = Color(0xFFEF4444);

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  late final AnimationController _laser = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  late final AnimationController _found = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _done = false;
  bool _pickingImage = false;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _toastTimer?.cancel();
    _laser.dispose();
    _found.dispose();
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // We pass our own controller, so the camera's lifecycle is ours to run.
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_done) unawaited(_controller.start());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        unawaited(_controller.stop());
      default:
        break;
    }
  }

  // ── Results ───────────────────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null) continue;
      final payload = parseCryptoQr(raw);
      if (payload != null) {
        _finish(payload);
        return;
      }
    }
    _showToast('That QR code doesn’t contain a wallet address');
  }

  Future<void> _finish(CryptoQrPayload payload) async {
    _done = true;
    HapticFeedback.mediumImpact();
    _laser.stop();
    setState(() => _toast = null);
    await _found.forward();
    unawaited(_controller.stop());
    if (mounted) Navigator.of(context).pop(payload);
  }

  void _showToast(String message) {
    HapticFeedback.lightImpact();
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  Future<void> _pickFromGallery() async {
    if (_pickingImage || _done) return;
    setState(() => _pickingImage = true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      final capture = await _controller.analyzeImage(
        image.path,
        formats: const [BarcodeFormat.qrCode],
      );
      if (!mounted) return;
      if (capture == null || capture.barcodes.isEmpty) {
        _showToast('No QR code found in that image');
        return;
      }
      _onDetect(capture);
    } on UnsupportedError {
      if (mounted) _showToast('Reading images isn’t supported on this device');
    } catch (_) {
      if (mounted) _showToast('Couldn’t read that image — try another one');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final side = (size.width * 0.72).clamp(200.0, 320.0);
            final window = Rect.fromCenter(
              center: Offset(size.width / 2, size.height * 0.44),
              width: side,
              height: side,
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: MobileScanner(
                    controller: _controller,
                    fit: BoxFit.cover,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) =>
                        _CameraError(error: error),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _laser,
                        _found,
                        _controller,
                      ]),
                      builder: (context, _) => _controller.value.error != null
                          ? const SizedBox.shrink()
                          : CustomPaint(
                              painter: _ScannerOverlayPainter(
                                window: window,
                                laser: Curves.easeInOutSine.transform(
                                  _laser.value,
                                ),
                                found: _found.value,
                                showLaser: !_done,
                              ),
                            ),
                    ),
                  ),
                ),
                // Success tick that pops in the middle of the window.
                Positioned.fromRect(
                  rect: window,
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _found,
                        builder: (context, child) => Transform.scale(
                          scale: Curves.elasticOut.transform(_found.value),
                          child: Opacity(
                            opacity: _found.value.clamp(0.0, 1.0),
                            child: child,
                          ),
                        ),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _success,
                            boxShadow: [
                              BoxShadow(
                                color: _success.withValues(alpha: 0.5),
                                blurRadius: 28,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Top bar.
                Positioned(
                  top: padding.top + 8,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      _GlassButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Expanded(
                        child: Text(
                          'Scan QR code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: _controller,
                        builder: (context, state, _) {
                          final torch = state.torchState;
                          if (torch == TorchState.unavailable) {
                            return const SizedBox(width: 44);
                          }
                          final on = torch == TorchState.on;
                          return _GlassButton(
                            icon: on
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            active: on,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _controller.toggleTorch();
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Instructions under the window.
                Positioned(
                  top: window.bottom + 28,
                  left: 32,
                  right: 32,
                  child: const Column(
                    children: [
                      Text(
                        'Point at a deposit QR code',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'From another wallet or exchange — the address fills in automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                // Rejection toast, just above the window.
                Positioned(
                  top: window.top - 62,
                  left: 24,
                  right: 24,
                  child: IgnorePointer(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween(begin: 0.85, end: 1.0).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                          child: child,
                        ),
                      ),
                      child: _toast == null
                          ? const SizedBox(key: ValueKey('none'), height: 44)
                          : Center(
                              key: ValueKey(_toast),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: _danger,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _toast!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                // Gallery button.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: padding.bottom + 32,
                  child: Center(
                    child: _GalleryButton(
                      loading: _pickingImage,
                      onTap: _pickFromGallery,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Overlay ─────────────────────────────────────────────────────────────────

class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter({
    required this.window,
    required this.laser,
    required this.found,
    required this.showLaser,
  });

  final Rect window;
  final double laser;
  final double found;
  final bool showLaser;

  static const _radius = 26.0;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      window,
      const Radius.circular(_radius),
    );

    // Dim everything outside the window.
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(hole),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.58),
    );

    // Corner brackets — primary while scanning, green once found, and they
    // squeeze in a touch on success.
    final color = Color.lerp(AppColors.primary, _success, found)!;
    final inset = 4.0 * found;
    final r = window.deflate(inset);
    const len = 34.0;
    final bracket = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    for (final corner in _corners(r, len)) {
      canvas.drawPath(corner, glow);
      canvas.drawPath(corner, bracket);
    }

    // Sweeping laser line with a soft trail.
    if (showLaser) {
      final y = r.top + 18 + (r.height - 36) * laser;
      final line = Rect.fromLTRB(r.left + 18, y - 1.5, r.right - 18, y + 1.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(line, const Radius.circular(2)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0),
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0),
            ],
          ).createShader(line),
      );
      final trail = Rect.fromLTRB(r.left + 18, y - 26, r.right - 18, y);
      canvas.drawRect(
        trail,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.22),
              AppColors.primary.withValues(alpha: 0),
            ],
          ).createShader(trail),
      );
    }
  }

  Iterable<Path> _corners(Rect r, double len) sync* {
    const c = _radius;
    yield Path()
      ..moveTo(r.left, r.top + len)
      ..lineTo(r.left, r.top + c)
      ..arcToPoint(Offset(r.left + c, r.top), radius: const Radius.circular(c))
      ..lineTo(r.left + len, r.top);
    yield Path()
      ..moveTo(r.right - len, r.top)
      ..lineTo(r.right - c, r.top)
      ..arcToPoint(Offset(r.right, r.top + c), radius: const Radius.circular(c))
      ..lineTo(r.right, r.top + len);
    yield Path()
      ..moveTo(r.right, r.bottom - len)
      ..lineTo(r.right, r.bottom - c)
      ..arcToPoint(
        Offset(r.right - c, r.bottom),
        radius: const Radius.circular(c),
      )
      ..lineTo(r.right - len, r.bottom);
    yield Path()
      ..moveTo(r.left + len, r.bottom)
      ..lineTo(r.left + c, r.bottom)
      ..arcToPoint(
        Offset(r.left, r.bottom - c),
        radius: const Radius.circular(c),
      )
      ..lineTo(r.left, r.bottom - len);
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter old) =>
      old.window != window ||
      old.laser != laser ||
      old.found != found ||
      old.showLaser != showLaser;
}

// ─── Controls ────────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.16),
          ),
          child: Icon(
            icon,
            size: 22,
            color: active ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GalleryButton extends StatelessWidget {
  const _GalleryButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: loading
                    ? const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      )
                    : const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Upload from gallery',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
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

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                denied
                    ? Icons.no_photography_outlined
                    : Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                denied ? 'Camera access is off' : 'Camera unavailable',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? 'Allow Crownex to use the camera in your phone’s Settings, '
                          'or upload a screenshot of the QR code instead.'
                    : 'You can still upload a screenshot of the QR code.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
