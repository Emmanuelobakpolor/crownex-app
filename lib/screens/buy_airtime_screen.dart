import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/vtu.dart';
import '../models/wallet.dart';
import '../services/api_exception.dart';
import '../services/user_session.dart';
import '../services/vtu_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'airtime_pin_screen.dart';

class AirtimeNetwork {
  const AirtimeNetwork({
    required this.subcategoryId,
    required this.name,
    required this.color,
    required this.logoText,
    this.logoTextColor = Colors.white,
    this.logoAsset,
  });

  final String subcategoryId;
  final String name;
  final Color color;
  final String logoText;
  final Color logoTextColor;
  final String? logoAsset;
}

class RecentAirtimeContact {
  const RecentAirtimeContact({required this.networkName, required this.phone});

  final String networkName;
  final String phone;
}

/// Best-effort brand styling for a network name returned by PluginNG —
/// falls back to a generic text badge for anything unrecognized or without
/// a bundled logo asset (see assets/images/networks/).
({Color color, String logoText, Color logoTextColor, String? logoAsset}) _styleFor(
  String name,
) {
  final n = name.toLowerCase();
  if (n.contains('mtn')) {
    return (
      color: const Color(0xFFFFCC00),
      logoText: 'MTN',
      logoTextColor: const Color(0xFF1A1A1A),
      logoAsset: 'assets/images/networks/mtn.png',
    );
  }
  if (n.contains('glo')) {
    return (
      color: const Color(0xFF50B848),
      logoText: 'glo',
      logoTextColor: Colors.white,
      logoAsset: 'assets/images/networks/glo.png',
    );
  }
  if (n.contains('airtel')) {
    return (
      color: const Color(0xFFED1C24),
      logoText: 'A',
      logoTextColor: Colors.white,
      logoAsset: 'assets/images/networks/airtel.png',
    );
  }
  if (n.contains('9mobile') || n.contains('etisalat')) {
    return (
      color: const Color(0xFF006F3C),
      logoText: '9m',
      logoTextColor: Colors.white,
      logoAsset: null,
    );
  }
  return (
    color: AppColors.primary,
    logoText: name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
    logoTextColor: Colors.white,
    logoAsset: null,
  );
}

const _quickAmounts = [100, 200, 400, 500, 1000, 2000];

/// Buy Airtime — form, confirm sheet, success sheet.
class BuyAirtimeScreen extends StatefulWidget {
  const BuyAirtimeScreen({super.key});

  @override
  State<BuyAirtimeScreen> createState() => _BuyAirtimeScreenState();
}

class _BuyAirtimeScreenState extends State<BuyAirtimeScreen> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();

  bool _loading = true;
  String? _loadError;
  List<AirtimeNetwork> _networks = const [];
  List<RecentAirtimeContact> _recents = const [];
  AirtimeNetwork? _selectedNetwork;
  double _ngnBalance = 0;
  int? _selectedQuickAmount;
  VtuTransaction? _lastTx;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserSession>().user;
    if (user != null && user.phone.isNotEmpty) {
      _phoneController.text = user.phone;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        VtuService.instance.getCatalogue(),
        WalletService.instance.getWallet(),
        VtuService.instance.getTransactions(),
      ]);
      final catalogue = results[0] as VtuCatalogue;
      final wallet = results[1] as WalletBalance;
      final transactions = results[2] as List<VtuTransaction>;
      final networks = catalogue.airtime.map((n) {
        final style = _styleFor(n.name);
        return AirtimeNetwork(
          subcategoryId: n.subcategoryId,
          name: n.name,
          color: style.color,
          logoText: style.logoText,
          logoTextColor: style.logoTextColor,
          logoAsset: style.logoAsset,
        );
      }).toList();

      final recents = <RecentAirtimeContact>[];
      final seenPhones = <String>{};
      for (final tx in transactions) {
        if (tx.service != 'airtime' || !seenPhones.add(tx.phone)) continue;
        recents.add(
          RecentAirtimeContact(networkName: tx.network, phone: tx.phone),
        );
        if (recents.length >= 4) break;
      }

      if (!mounted) return;
      setState(() {
        _networks = networks;
        _recents = recents;
        _selectedNetwork = networks.isNotEmpty ? networks.first : null;
        _ngnBalance = wallet.ngnBalance;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load networks. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  double? get _amount {
    final raw = _amountController.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String? get _amountHint {
    final amount = _amount;
    if (amount == null) return null;
    if (amount < 50) return 'Minimum airtime is ₦50';
    if (amount > _ngnBalance) return 'Amount exceeds available balance';
    return null;
  }

  bool get _canContinue {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final amount = _amount;
    return _selectedNetwork != null &&
        phone.length >= 10 &&
        amount != null &&
        amount >= 50;
  }

  void _selectRecent(RecentAirtimeContact contact) {
    if (_networks.isEmpty) return;
    setState(() {
      _phoneController.text = contact.phone;
      _selectedNetwork = _networks.firstWhere(
        (n) => n.name.toLowerCase() == contact.networkName.toLowerCase(),
        orElse: () => _selectedNetwork ?? _networks.first,
      );
    });
  }

  void _selectQuickAmount(int amount) {
    setState(() {
      _selectedQuickAmount = amount;
      _amountController.text = _formatAmount(amount.toDouble());
    });
    _amountFocus.unfocus();
  }

  String _formatAmount(double value) {
    if (value == value.roundToDouble()) {
      final n = value.round();
      final s = n.toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    return value.toStringAsFixed(2);
  }

  String _displayPhoneInternational(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length >= 10) {
      return '+234 ${digits.substring(1)}';
    }
    if (digits.startsWith('234')) return '+$digits';
    return digits.isEmpty ? raw : '+$digits';
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    final network = _selectedNetwork;
    if (network == null) return;
    final amount = _amount!;
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _ConfirmPurchaseSheet(
        amount: amount,
        phoneDisplay: _displayPhoneInternational(phone),
        network: network,
        balance: _ngnBalance,
        onConfirm: () => Navigator.of(ctx).pop(true),
        onClose: () => Navigator.of(ctx).pop(false),
      ),
    );

    if (confirmed != true || !mounted) return;

    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AirtimePinScreen(
          amount: amount,
          phone: phone,
          networkName: network.name,
          onSubmit: (pin) async {
            _lastTx = await VtuService.instance.buyAirtime(
              subcategoryId: network.subcategoryId,
              network: network.name,
              phone: phone,
              amount: amount,
              transactionPin: pin,
            );
          },
        ),
      ),
    );

    if (paid == true && mounted) {
      final pending = _lastTx?.status == VtuStatus.pending;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        isDismissible: false,
        enableDrag: false,
        builder: (ctx) => _SuccessSheet(
          networkName: network.name,
          phone: phone,
          amount: amount,
          pending: pending,
          onDone: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pop(); // back to home
          },
        ),
      );
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_loadError != null) {
      return Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFDC2626),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              AuthPrimaryButton(label: 'Retry', onPressed: _load),
            ],
          ),
        ),
      );
    }

    final amountHint = _amountHint;

    return SingleChildScrollView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BalancePill(
            balance: _ngnBalance,
            formatAmount: _formatAmount,
          ),
          if (_recents.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionLabel('Recent'),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recents.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = _recents[i];
                  return _RecentChip(
                    contact: c,
                    onTap: () => _selectRecent(c),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 22),
          const _SectionLabel('Phone number'),
          const SizedBox(height: 10),
          _PhoneField(
            controller: _phoneController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Network'),
          const SizedBox(height: 12),
          _NetworkRow(
            networks: _networks,
            selected: _selectedNetwork,
            onSelect: (n) => setState(() => _selectedNetwork = n),
          ),
          const SizedBox(height: 22),
          _AmountCard(
            controller: _amountController,
            focusNode: _amountFocus,
            amountHint: amountHint,
            onChanged: (v) {
              setState(() {
                final parsed = double.tryParse(v.replaceAll(',', ''));
                _selectedQuickAmount =
                    parsed != null && parsed == parsed.roundToDouble()
                        ? parsed.round()
                        : null;
                if (_selectedQuickAmount != null &&
                    !_quickAmounts.contains(_selectedQuickAmount)) {
                  _selectedQuickAmount = null;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          _QuickAmountGrid(
            amounts: _quickAmounts,
            selected: _selectedQuickAmount,
            onSelect: _selectQuickAmount,
          ),
          const SizedBox(height: 16),
          const _InfoBanner(
            text:
                'Airtime is delivered instantly after PIN confirmation. '
                'Minimum purchase is ₦50.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final amount = _amount;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const _ScreenHeader(
                title: 'Buy Airtime',
                subtitle: 'Top up any Nigerian number',
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildBody(),
                ),
              ),
              _BottomBar(
                bottomPad: bottomPad,
                enabled: _canContinue,
                amount: amount,
                onPressed: _onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared chrome ───────────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  const _BalancePill({
    required this.balance,
    required this.formatAmount,
  });

  final double balance;
  final String Function(double) formatAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet balance',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Available for airtime',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₦${formatAmount(balance)}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E4FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.bottomPad,
    required this.enabled,
    required this.onPressed,
    this.amount,
  });

  final double bottomPad;
  final bool enabled;
  final VoidCallback onPressed;
  final double? amount;

  String _fmt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final label = amount != null && enabled
        ? 'Continue · ₦${_fmt(amount!)}'
        : 'Continue';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: AuthPrimaryButton(
        label: label,
        enabled: enabled,
        onPressed: onPressed,
      ),
    );
  }
}

// ─── Recent ──────────────────────────────────────────────────────────────────

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.contact, required this.onTap});

  final RecentAirtimeContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(contact.networkName);
    final shortPhone = contact.phone.length > 7
        ? '…${contact.phone.substring(contact.phone.length - 4)}'
        : contact.phone;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 88,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LogoBadge(
                color: style.color,
                logoText: style.logoText,
                logoTextColor: style.logoTextColor,
                logoAsset: style.logoAsset,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                shortPhone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                contact.networkName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Network ─────────────────────────────────────────────────────────────────

class _NetworkRow extends StatelessWidget {
  const _NetworkRow({
    required this.networks,
    required this.selected,
    required this.onSelect,
  });

  final List<AirtimeNetwork> networks;
  final AirtimeNetwork? selected;
  final ValueChanged<AirtimeNetwork> onSelect;

  @override
  Widget build(BuildContext context) {
    if (networks.isEmpty) {
      return const Text(
        'No networks available',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: networks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final n = networks[i];
          final isSelected = n.subcategoryId == selected?.subcategoryId;
          return _NetworkCard(
            network: n,
            selected: isSelected,
            onTap: () => onSelect(n),
          );
        },
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.network,
    required this.selected,
    required this.onTap,
  });

  final AirtimeNetwork network;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 86,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: 0.9),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _NetworkLogo(network: network, size: 40),
                  if (selected)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                network.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkLogo extends StatelessWidget {
  const _NetworkLogo({required this.network, required this.size});

  final AirtimeNetwork network;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _LogoBadge(
      color: network.color,
      logoText: network.logoText,
      logoTextColor: network.logoTextColor,
      logoAsset: network.logoAsset,
      size: size,
      tight: network.name.toLowerCase() == 'mtn',
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({
    required this.color,
    required this.logoText,
    required this.logoTextColor,
    required this.size,
    this.logoAsset,
    this.tight = false,
  });

  final Color color;
  final String logoText;
  final Color logoTextColor;
  final double size;
  final String? logoAsset;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final asset = logoAsset;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: asset != null ? Colors.white : color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: asset != null
          ? Padding(
              padding: EdgeInsets.all(size * 0.16),
              child: Image.asset(asset, fit: BoxFit.contain),
            )
          : Center(
              child: Text(
                logoText,
                style: TextStyle(
                  color: logoTextColor,
                  fontWeight: FontWeight.w800,
                  fontSize: size * (logoText.length > 2 ? 0.28 : 0.38),
                  letterSpacing: tight ? -0.5 : 0,
                ),
              ),
            ),
    );
  }
}

// ─── Fields ──────────────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      onChanged: onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.3,
      ),
      decoration: InputDecoration(
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 12, right: 8),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.smartphone_rounded,
            color: AppColors.primary,
            size: 18,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 52,
          minHeight: 36,
        ),
        hintText: '0800 000 0000',
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.amountHint,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String? amountHint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_android_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'Airtime amount',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.number,
            onChanged: onChanged,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
            ],
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -1.2,
              height: 1.1,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted.withValues(alpha: 0.45),
                letterSpacing: -1.2,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(right: 4, top: 6),
                child: Text(
                  '₦',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              amountHint ?? 'Minimum ₦50 · Instant delivery',
              key: ValueKey(amountHint ?? 'default'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: amountHint != null
                    ? const Color(0xFFDC2626)
                    : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAmountGrid extends StatelessWidget {
  const _QuickAmountGrid({
    required this.amounts,
    required this.selected,
    required this.onSelect,
  });

  final List<int> amounts;
  final int? selected;
  final ValueChanged<int> onSelect;

  String _label(int amount) {
    final s = amount.toString();
    final buf = StringBuffer('₦');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: amounts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.35,
      ),
      itemBuilder: (context, index) {
        final amount = amounts[index];
        final isSelected = selected == amount;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onSelect(amount),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                _label(amount),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Confirm purchase sheet ──────────────────────────────────────────────────

class _ConfirmPurchaseSheet extends StatelessWidget {
  const _ConfirmPurchaseSheet({
    required this.amount,
    required this.phoneDisplay,
    required this.network,
    required this.balance,
    required this.onConfirm,
    required this.onClose,
  });

  final double amount;
  final String phoneDisplay;
  final AirtimeNetwork network;
  final double balance;
  final VoidCallback onConfirm;
  final VoidCallback onClose;

  String _money(double v) {
    final whole = v.floor();
    final frac = ((v - whole) * 100).round().toString().padLeft(2, '0');
    final s = whole.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '₦${buf.toString()}.$frac';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 14, 24, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Confirm Purchase',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Material(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Airtime amount',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _money(amount),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _DetailRow(label: 'Phone number', value: phoneDisplay),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Network',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _LogoBadge(
                color: network.color,
                logoText: network.logoText,
                logoTextColor: network.logoTextColor,
                logoAsset: network.logoAsset,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                network.name,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _DetailRow(
            label: 'Wallet balance',
            value: _money(balance),
            valueBold: true,
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Confirm Payment',
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueBold = false,
  });

  final String label;
  final String value;
  final bool valueBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: valueBold ? FontWeight.w700 : FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Success sheet ───────────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({
    required this.networkName,
    required this.phone,
    required this.amount,
    required this.onDone,
    this.pending = false,
  });

  final String networkName;
  final String phone;
  final double amount;
  final VoidCallback onDone;
  final bool pending;

  String _money(double v) {
    final whole = v.floor();
    final s = whole.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '₦${buf.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 28, 24, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: pending
                      ? [
                          AppColors.primary.withValues(alpha: 0.14),
                          AppColors.primary.withValues(alpha: 0.06),
                        ]
                      : [
                          const Color(0xFFD1FAE5),
                          const Color(0xFFECFDF5),
                        ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                pending ? Icons.schedule_rounded : Icons.check_rounded,
                size: 36,
                color: pending ? AppColors.primary : const Color(0xFF059669),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            pending ? 'Purchase Submitted' : 'Purchase Successful',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            pending
                ? 'Your $networkName airtime purchase for $phone is being '
                    'processed. We\'ll update your transaction history once '
                    'it\'s confirmed.'
                : 'You successfully purchased ${_money(amount)} $networkName '
                    'airtime for $phone.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 26),
          AuthPrimaryButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}
