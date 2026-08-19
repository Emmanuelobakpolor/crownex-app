import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/giftcard.dart';
import '../services/giftcard_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';

/// GET /giftcards/history/ — gift card purchase history, grouped by day.
/// Status (pending/completed/failed) always reflects the server's record,
/// which is the source of truth once the Reloadly webhook lands for
/// brands that fulfil asynchronously.
class GiftCardHistoryScreen extends StatefulWidget {
  const GiftCardHistoryScreen({super.key});

  @override
  State<GiftCardHistoryScreen> createState() => _GiftCardHistoryScreenState();
}

class _GiftCardHistoryScreenState extends State<GiftCardHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<GiftCardPurchase> _purchases = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final purchases = await GiftCardService.instance.getHistory();
      if (!mounted) return;
      setState(() {
        _purchases = purchases;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load purchase history.';
        _loading = false;
      });
    }
  }

  Map<String, List<GiftCardPurchase>> get _grouped {
    final grouped = <String, List<GiftCardPurchase>>{};
    for (final p in _purchases) {
      final label = _dateLabel(p.createdAt);
      grouped.putIfAbsent(label, () => []).add(p);
    }
    return grouped;
  }

  static String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _openDetail(GiftCardPurchase purchase) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _PurchaseDetailSheet(purchase: purchase),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Colors.white,
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
                        child: AuthBackButton(onPressed: () => Navigator.of(context).pop()),
                      ),
                      const Text(
                        'Gift Card History',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: _buildBody(grouped),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, List<GiftCardPurchase>> grouped) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Center(child: Text(_error!, style: const TextStyle(color: AppColors.textMuted))),
        ],
      );
    }

    if (grouped.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 100), _EmptyState()],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: grouped.length,
      itemBuilder: (context, sectionIndex) {
        final label = grouped.keys.elementAt(sectionIndex);
        final items = grouped[label]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: sectionIndex == 0 ? 0 : 20, bottom: 10),
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
            ),
            for (final p in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PurchaseRow(purchase: p, onTap: () => _openDetail(p)),
              ),
          ],
        );
      },
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({required this.purchase, required this.onTap});

  final GiftCardPurchase purchase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F1F5),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.card_giftcard_rounded, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchase.brand,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '\$${purchase.unitPriceUsd.toStringAsFixed(2)} · ${purchase.reference}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '-₦${_formatAmount(purchase.amountNgn)}',
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                  ),
                  const SizedBox(height: 5),
                  _StatusPill(status: purchase.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final GiftCardStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      GiftCardStatus.completed => ('Completed', const Color(0xFF16A34A)),
      GiftCardStatus.pending => ('Processing', const Color(0xFFD97706)),
      GiftCardStatus.failed => ('Failed', const Color(0xFFDC2626)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.card_giftcard_rounded, size: 32, color: AppColors.primary),
        ),
        const SizedBox(height: 18),
        const Text(
          'No gift cards yet',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your gift card purchases will show up here',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _PurchaseDetailSheet extends StatelessWidget {
  const _PurchaseDetailSheet({required this.purchase});

  final GiftCardPurchase purchase;

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            purchase.brand,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${purchase.unitPriceUsd.toStringAsFixed(2)} · ${_formatAmount(purchase.amountNgn)}',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (purchase.status == GiftCardStatus.completed && purchase.redeemCode.isNotEmpty) ...[
            _Field(
              label: 'Card number',
              value: purchase.redeemCode,
              onCopy: () => _copy(context, 'Card number', purchase.redeemCode),
            ),
            if (purchase.redeemPin.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Field(
                label: 'PIN',
                value: purchase.redeemPin,
                onCopy: () => _copy(context, 'PIN', purchase.redeemPin),
              ),
            ],
          ] else if (purchase.status == GiftCardStatus.pending)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'Still processing — your redeem code will appear here once the provider delivers it.',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
              ),
            )
          else if (purchase.status == GiftCardStatus.failed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(14)),
              child: Text(
                purchase.note.isNotEmpty ? purchase.note : 'This purchase failed and was refunded.',
                style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFFDC2626)),
              ),
            ),
          const SizedBox(height: 20),
          Text('Reference: ${purchase.reference}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, required this.onCopy});

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(onTap: onCopy, child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

String _formatAmount(double v) {
  final whole = v.floor();
  final frac = ((v - whole) * 100).round().toString().padLeft(2, '0');
  final s = whole.toString();
  final buf = StringBuffer('₦');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${buf.toString()}.$frac';
}
