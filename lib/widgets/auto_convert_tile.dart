import 'package:flutter/material.dart';

import '../services/api_exception.dart';
import '../services/crypto_service.dart';
import '../theme/app_colors.dart';

/// Auto-convert incoming crypto deposits to NGN. Backed by
/// /crypto/settings/; only affects deposits that arrive after the change.
/// Used in Settings and on the deposit screen — each instance loads the
/// current value itself, so both always show what the server has.
class AutoConvertTile extends StatefulWidget {
  const AutoConvertTile({super.key, this.subtitleBuilder});

  /// Line under the title for the current value (null while loading);
  /// defaults to a generic description.
  final String Function(bool? enabled)? subtitleBuilder;

  @override
  State<AutoConvertTile> createState() => _AutoConvertTileState();
}

class _AutoConvertTileState extends State<AutoConvertTile> {
  bool? _enabled; // null while loading or if the load failed
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final enabled = await CryptoService.instance.getAutoConvertDeposits();
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {
      // Leave the switch disabled; the user can reopen settings to retry.
    }
  }

  Future<bool> _confirmEnable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Auto-convert deposits?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Crypto you receive from an external wallet will be sold for naira '
          'at the live rate (minus the normal sell fee) and added to your NGN '
          'wallet. Very small deposits, and coins without a naira market, '
          'stay as crypto.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Turn on',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _toggle(bool value) async {
    if (value && !await _confirmEnable()) return;
    if (!mounted) return;
    final previous = _enabled;
    setState(() {
      _enabled = value;
      _saving = true;
    });
    try {
      final saved = await CryptoService.instance.setAutoConvertDeposits(value);
      if (mounted) setState(() => _enabled = saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not update this setting.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF1D6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.currency_exchange_rounded,
              size: 18,
              color: Color(0xFFE59A0B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto-convert deposits to NGN',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitleBuilder?.call(_enabled) ??
                      'Sell incoming crypto at the live rate',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _enabled ?? false,
            onChanged: _enabled == null || _saving ? null : _toggle,
          ),
        ],
      ),
    );
  }
}
