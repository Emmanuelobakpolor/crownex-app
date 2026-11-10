import 'package:flutter/material.dart';

import '../services/beneficiary_store.dart';
import '../theme/app_colors.dart';

/// Header pill — "Saved · 12" — that opens [showBeneficiariesSheet].
class SavedBeneficiariesButton extends StatelessWidget {
  const SavedBeneficiariesButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                count > 0 ? 'Saved · $count' : 'Saved',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Send again" sheet: search, tap to pick, long-press to delete. Returns
/// the picked beneficiary, or null if dismissed. Deletions are persisted
/// immediately, so callers should reload their count afterwards.
Future<Beneficiary?> showBeneficiariesSheet({
  required BuildContext context,
  required BeneficiaryKind kind,
  required int? userId,
  required List<Beneficiary> beneficiaries,
  String searchHint = 'Search name, bank or number',
  Widget Function(Beneficiary b)? leadingBuilder,
}) {
  return showModalBottomSheet<Beneficiary>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _BeneficiariesSheet(
      kind: kind,
      userId: userId,
      initial: beneficiaries,
      searchHint: searchHint,
      leadingBuilder: leadingBuilder,
    ),
  );
}

class _BeneficiariesSheet extends StatefulWidget {
  const _BeneficiariesSheet({
    required this.kind,
    required this.userId,
    required this.initial,
    required this.searchHint,
    this.leadingBuilder,
  });

  final BeneficiaryKind kind;
  final int? userId;
  final List<Beneficiary> initial;
  final String searchHint;
  final Widget Function(Beneficiary b)? leadingBuilder;

  @override
  State<_BeneficiariesSheet> createState() => _BeneficiariesSheetState();
}

class _BeneficiariesSheetState extends State<_BeneficiariesSheet> {
  late List<Beneficiary> _items = widget.initial;
  String _query = '';

  Future<void> _confirmDelete(Beneficiary b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove beneficiary?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          '${b.title} will be removed from your saved list.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final updated = await BeneficiaryStore.instance.remove(
      widget.kind,
      widget.userId,
      b.key,
    );
    if (mounted) setState(() => _items = updated);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((b) => b.matches(_query)).toList();
    final bottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SAVED',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Send again.',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to fill the form. Long press to delete.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: AppColors.surfaceMuted,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? _EmptyState(hasAny: _items.isNotEmpty)
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: AppColors.border),
                        itemBuilder: (_, i) {
                          final b = filtered[i];
                          return _BeneficiaryRow(
                            beneficiary: b,
                            leading: widget.leadingBuilder?.call(b) ??
                                BeneficiaryInitialsAvatar(name: b.title),
                            onTap: () => Navigator.of(context).pop(b),
                            onLongPress: () => _confirmDelete(b),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeneficiaryRow extends StatelessWidget {
  const _BeneficiaryRow({
    required this.beneficiary,
    required this.leading,
    required this.onTap,
    required this.onLongPress,
  });

  final Beneficiary beneficiary;
  final Widget leading;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final trailing = beneficiary.trailing;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      beneficiary.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (beneficiary.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        beneficiary.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null && trailing.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAny});

  final bool hasAny;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAny ? Icons.search_off_rounded : Icons.bookmark_border_rounded,
              size: 40,
              color: AppColors.textMuted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            Text(
              hasAny ? 'No match found' : 'No saved beneficiaries yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (!hasAny) ...[
              const SizedBox(height: 6),
              Text(
                'Recipients are saved automatically after a successful transaction.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Round initials badge — default leading for a saved beneficiary.
class BeneficiaryInitialsAvatar extends StatelessWidget {
  const BeneficiaryInitialsAvatar({super.key, required this.name, this.size = 44});

  final String name;
  final double size;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(p[0]))
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.32,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
