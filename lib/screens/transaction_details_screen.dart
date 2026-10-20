import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_transaction.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';

/// Full details for one row of the merged feed, plus a receipt that can be
/// shared as an image. Everything shown comes from the [AppTransaction]
/// already loaded by the list — no extra request.
class TransactionDetailsScreen extends StatefulWidget {
  const TransactionDetailsScreen({super.key, required this.tx});

  final AppTransaction tx;

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  final _receiptKey = GlobalKey();
  final _shareButtonKey = GlobalKey();
  bool _sharing = false;

  AppTransaction get tx => widget.tx;

  Future<void> _shareReceipt() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _receiptKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) throw StateError('Could not render receipt.');

      final name = tx.reference.isNotEmpty ? tx.reference : tx.id;
      final buttonBox =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'crownex-receipt-$name.png',
            ),
          ],
          fileNameOverrides: ['crownex-receipt-$name.png'],
          text: 'CrownEx transaction receipt',
          // Required on iPad, where the share sheet is a popover.
          sharePositionOrigin: buttonBox == null
              ? null
              : buttonBox.localToGlobal(Offset.zero) & buttonBox.size,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share receipt. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _copyReference() {
    Clipboard.setData(ClipboardData(text: tx.reference));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reference copied')));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AuthBackButton(
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const Text(
                        'Transaction Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: RepaintBoundary(
                    key: _receiptKey,
                    child: _Receipt(tx: tx),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Row(
                  children: [
                    if (tx.reference.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyReference,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy ref'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        key: _shareButtonKey,
                        onPressed: _sharing ? null : _shareReceipt,
                        icon: _sharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.ios_share_rounded, size: 18),
                        label: const Text('Share receipt'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The part that is captured into the shared image — kept self-contained
/// (own white background, brand line, footer) so it reads on its own.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.tx});

  final AppTransaction tx;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (tx.status) {
      AppTxStatus.completed => ('Successful', const Color(0xFF16A34A)),
      AppTxStatus.pending => ('Pending', const Color(0xFFD97706)),
      AppTxStatus.failed => ('Failed', const Color(0xFFDC2626)),
    };
    final amountText =
        tx.amountLabel ??
        '${tx.isCredit ? '+' : '-'}₦${formatNaira(tx.amount)}';

    final rows = <TxDetail>[
      ...tx.details,
      (label: 'Status', value: statusLabel),
      (label: 'Date', value: formatTxDateTime(tx.createdAt)),
      if (tx.reference.isNotEmpty) (label: 'Reference', value: tx.reference),
      if (tx.note.trim().isNotEmpty) (label: 'Note', value: tx.note.trim()),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'CrownEx',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Transaction receipt',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 22),
          Text(
            tx.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            amountText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 6),
          for (final row in rows)
            _DetailRow(label: row.label, value: row.value),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          const Text(
            'Thank you for using CrownEx.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1234567.5 -> "1,234,567.50"
String formatNaira(double v) {
  final parts = v.toStringAsFixed(2).split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0 && whole[i - 1] != '-') {
      buf.write(',');
    }
    buf.write(whole[i]);
  }
  return '$buf.${parts[1]}';
}

/// "Oct 20, 2026 • 3:05 PM" in the device's local time.
String formatTxDateTime(DateTime date) {
  const months = [
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
  final d = date.toLocal();
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour < 12 ? 'AM' : 'PM';
  return '${months[d.month - 1]} ${d.day}, ${d.year} • $hour:$minute $period';
}
