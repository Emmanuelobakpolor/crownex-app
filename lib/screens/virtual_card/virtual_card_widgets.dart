import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../widgets/auth_widgets.dart';

const kCardPurple = Color(0xFF3D1A6E);
const kFieldFill = Color(0xFFF3F1F6);
const kFieldBorder = Color(0xFFD4C8E0);

class CardFlowHeader extends StatelessWidget {
  const CardFlowHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (onBack != null)
              Align(
                alignment: Alignment.centerLeft,
                child: AuthBackButton(onPressed: onBack),
              ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            if (trailing != null)
              Align(alignment: Alignment.centerRight, child: trailing!),
          ],
        ),
      ),
    );
  }
}

/// Blue prepaid card visual matching designs.
class VirtualCardVisual extends StatelessWidget {
  const VirtualCardVisual({
    super.key,
    this.last4 = '78',
    this.compact = false,
    this.angled = false,
    this.balanceDisplay,
  });

  final String last4;
  final bool compact;
  final bool angled;

  /// USD balance to show instead of the masked '$ *****' placeholder —
  /// only known once a real card exists (CardDashboard).
  final String? balanceDisplay;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      height: compact ? 176 : 196,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B3DCC),
            Color(0xFF062A8C),
            Color(0xFF031E66),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF062A8C).withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _CardPatternPainter()),
            ),
            Positioned(
              right: 8,
              top: 24,
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 88,
                color: const Color(0xFFFFC107).withValues(alpha: 0.9),
              ),
            ),
            Positioned(
              right: 28,
              bottom: 28,
              child: Icon(
                Icons.monetization_on_rounded,
                size: 56,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A4FE0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('👑', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '****  ****  ****  **$last4',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    balanceDisplay != null ? '\$$balanceDisplay' : '\$ *****',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!angled) return card;

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 0, top: 8),
      child: Transform.rotate(
        angle: -0.06,
        alignment: Alignment.centerRight,
        child: Transform.translate(
          offset: const Offset(28, 0),
          child: card,
        ),
      ),
    );
  }
}

class _CardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    for (var i = -2; i < 10; i++) {
      final y = i * 34.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-30, y, size.width + 60, 26),
          const Radius.circular(6),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VerifyFieldLabel extends StatelessWidget {
  const VerifyFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class VerifyTextField extends StatelessWidget {
  const VerifyTextField({
    super.key,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.onChanged,
    this.suffix,
    this.readOnly = false,
    this.onTap,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final bool readOnly;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      readOnly: readOnly,
      onTap: onTap,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: kFieldFill,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kFieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kFieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kCardPurple, width: 1.4),
        ),
      ),
    );
  }
}

class VerifySubmitButton extends StatelessWidget {
  const VerifySubmitButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.label = 'Submit',
  });

  final bool enabled;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (enabled) {
      return AuthPrimaryButton(label: label, onPressed: onPressed);
    }
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFC4B5D4), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          disabledForegroundColor: const Color(0xFFB09BC4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class UploadBox extends StatelessWidget {
  const UploadBox({
    super.key,
    required this.label,
    required this.onTap,
    this.fileName,
    this.icon = Icons.image_outlined,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;
  final String? fileName;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null && fileName!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: compact ? 16 : 22,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC4B5D4), width: 1.2),
        ),
        child: hasFile
            ? Row(
                children: [
                  Expanded(
                    child: Text(
                      fileName!,
                      style: const TextStyle(
                        color: kCardPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.upload_rounded, color: kCardPurple, size: 22),
                ],
              )
            : compact
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.upload_rounded,
                        color: kCardPurple,
                        size: 22,
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Icon(icon, color: kCardPurple, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
  });

  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Small hourglass used in pending rows.
class MiniHourglass extends StatelessWidget {
  const MiniHourglass({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.hourglass_top_rounded,
      size: size,
      color: const Color(0xFFFFB020),
    );
  }
}
