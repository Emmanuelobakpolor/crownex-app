import 'dart:async';

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

class _Recent {
  const _Recent({required this.networkName, required this.cardno});

  final String networkName;
  final String cardno;
}

/// Best-effort brand styling for a cable biller — uses bundled logo assets
/// from assets/images/networks/ when available.
({Color color, String logoText, String? logoAsset}) _styleFor(String name) {
  final n = name.toLowerCase();
  if (n.contains('dstv')) {
    return (
      color: const Color(0xFF0033A0),
      logoText: 'DSTV',
      logoAsset: 'assets/images/networks/dstv.png',
    );
  }
  if (n.contains('gotv')) {
    return (
      color: const Color(0xFF00A651),
      logoText: 'GOtv',
      logoAsset: 'assets/images/networks/gotv.webp',
    );
  }
  if (n.contains('startimes')) {
    return (
      color: const Color(0xFFED1C24),
      logoText: 'ST',
      logoAsset: 'assets/images/networks/startimes.webp',
    );
  }
  if (n.contains('showmax')) {
    return (
      color: const Color(0xFF1A1A2E),
      logoText: 'SM',
      logoAsset: 'assets/images/networks/showmax.png',
    );
  }
  return (
    color: AppColors.primary,
    logoText: name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
    logoAsset: null,
  );
}

/// Attempt to pull a customer name out of PluginNG's undocumented
/// /verify/card response shape.
String? _extractCustomerName(Map<String, dynamic> data) {
  for (final key in ['Customer_Name', 'customer_name', 'CustomerName', 'name']) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// Cable & TV — biller, bouquet, smartcard verify, PIN, success.
class CableTvScreen extends StatefulWidget {
  const CableTvScreen({super.key});

  @override
  State<CableTvScreen> createState() => _CableTvScreenState();
}

class _CableTvScreenState extends State<CableTvScreen> {
  final _phoneController = TextEditingController();
  final _smartcardController = TextEditingController();

  bool _loading = true;
  String? _loadError;
  double _ngnBalance = 0;
  List<VtuNetwork> _billers = const [];
  List<_Recent> _recents = const [];
  VtuNetwork? _selectedBiller;

  bool _bouquetsLoading = false;
  String? _bouquetError;
  List<BouquetOption> _bouquets = const [];
  int _selectedBouquetIndex = -1;

  Timer? _verifyDebounce;
  bool _verifying = false;
  String? _customerName;
  String? _verifyError;

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

  @override
  void dispose() {
    _verifyDebounce?.cancel();
    _phoneController.dispose();
    _smartcardController.dispose();
    super.dispose();
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

      final recents = <_Recent>[];
      final seenCards = <String>{};
      for (final tx in transactions) {
        if (tx.service != 'cable' || !seenCards.add(tx.cardNumber)) continue;
        recents.add(_Recent(networkName: tx.network, cardno: tx.cardNumber));
        if (recents.length >= 4) break;
      }

      if (!mounted) return;
      setState(() {
        _billers = catalogue.cable;
        _recents = recents;
        _ngnBalance = wallet.ngnBalance;
        _loading = false;
      });

      if (_billers.isNotEmpty) {
        unawaited(_selectBiller(_billers.first));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load billers. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _selectBiller(VtuNetwork biller) async {
    setState(() {
      _selectedBiller = biller;
      _bouquets = const [];
      _selectedBouquetIndex = -1;
      _bouquetsLoading = true;
      _bouquetError = null;
    });
    try {
      final bouquets = await VtuService.instance.getCableBouquets(biller.name);
      if (!mounted) return;
      setState(() {
        _bouquets = bouquets;
        _selectedBouquetIndex = bouquets.isNotEmpty ? 0 : -1;
        _bouquetsLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _bouquetError = e.message;
        _bouquetsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bouquetError = 'Could not load plans for this biller.';
        _bouquetsLoading = false;
      });
    }
    _maybeVerify();
  }

  void _onSmartcardChanged(String value) {
    setState(() {
      _customerName = null;
      _verifyError = null;
    });
    _verifyDebounce?.cancel();
    _verifyDebounce = Timer(const Duration(milliseconds: 500), _maybeVerify);
  }

  void _maybeVerify() {
    final biller = _selectedBiller;
    final cardno = _smartcardController.text.replaceAll(RegExp(r'\D'), '');
    if (biller == null || cardno.length < 10) return;
    _verifySmartcard(biller, cardno);
  }

  Future<void> _verifySmartcard(VtuNetwork biller, String cardno) async {
    setState(() => _verifying = true);
    try {
      final data = await VtuService.instance.verifySmartcard(
        network: biller.name,
        cardno: cardno,
      );
      if (!mounted) return;
      final name = _extractCustomerName(data);
      setState(() {
        _customerName = name;
        _verifyError = name == null ? 'Could not verify this smartcard number.' : null;
        _verifying = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifyError = e.message;
        _verifying = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifyError = 'Could not verify this smartcard number.';
        _verifying = false;
      });
    }
  }

  bool get _canContinue {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final cardno = _smartcardController.text.replaceAll(RegExp(r'\D'), '');
    return _selectedBiller != null &&
        phone.length >= 10 &&
        cardno.length >= 10 &&
        _selectedBouquetIndex >= 0 &&
        _selectedBouquetIndex < _bouquets.length;
  }

  String _money(double v) {
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

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    final biller = _selectedBiller!;
    final bouquet = _bouquets[_selectedBouquetIndex];
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final cardno = _smartcardController.text.replaceAll(RegExp(r'\D'), '');
    final amount = bouquet.amount ?? 0;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _ConfirmSheet(
        amount: amount,
        cardno: cardno,
        customerName: _customerName,
        biller: biller,
        bouquetName: bouquet.name,
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
          networkName: '${biller.name} ${bouquet.name}',
          onSubmit: (pin) async {
            _lastTx = await VtuService.instance.buyCable(
              subcategoryId: biller.subcategoryId,
              network: biller.name,
              phone: phone,
              cardno: cardno,
              variationCode: bouquet.variationCode,
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
        builder: (ctx) => _CableSuccessSheet(
          biller: biller.name,
          bouquetName: bouquet.name,
          cardno: cardno,
          pending: pending,
          onDone: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pop();
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
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              AuthPrimaryButton(label: 'Retry', onPressed: _load),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_recents.isNotEmpty) ...[
            const _SectionLabel('Recent'),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recents.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final r = _recents[i];
                  final style = _styleFor(r.networkName);
                  return _RecentChip(
                    recent: r,
                    style: style,
                    onTap: () {
                      final match = _billers.firstWhere(
                        (b) => b.name.toLowerCase() == r.networkName.toLowerCase(),
                        orElse: () => _billers.first,
                      );
                      _smartcardController.text = r.cardno;
                      _onSmartcardChanged(r.cardno);
                      if (match.subcategoryId != _selectedBiller?.subcategoryId) {
                        _selectBiller(match);
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
          ],
          const _SectionLabel('Biller'),
          const SizedBox(height: 12),
          if (_billers.isEmpty)
            const Text(
              'No cable billers available',
              style: TextStyle(color: AppColors.textMuted),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _billers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final b = _billers[i];
                  final selected = b.subcategoryId == _selectedBiller?.subcategoryId;
                  return _BillerCard(
                    biller: b,
                    selected: selected,
                    onTap: () => _selectBiller(b),
                  );
                },
              ),
            ),
          const SizedBox(height: 22),
          const _SectionLabel('Phone number'),
          const SizedBox(height: 10),
          _LabeledField(
            controller: _phoneController,
            icon: Icons.smartphone_rounded,
            hintText: '0800 000 0000',
            maxLength: 11,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Smartcard number'),
          const SizedBox(height: 10),
          _LabeledField(
            controller: _smartcardController,
            icon: Icons.credit_card_rounded,
            hintText: 'Enter smartcard number',
            maxLength: 12,
            onChanged: _onSmartcardChanged,
          ),
          if (_verifying) ...[
            const SizedBox(height: 8),
            const Text(
              'Verifying…',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ] else if (_customerName != null) ...[
            const SizedBox(height: 8),
            Text(
              _customerName!,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ] else if (_verifyError != null) ...[
            const SizedBox(height: 8),
            Text(
              _verifyError!,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626)),
            ),
          ],
          const SizedBox(height: 22),
          const _SectionLabel('Select bouquet'),
          const SizedBox(height: 12),
          if (_bouquetsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_bouquetError != null)
            Text(
              _bouquetError!,
              style: const TextStyle(color: AppColors.textSecondary),
            )
          else if (_bouquets.isEmpty)
            const Text(
              'No bouquets available for this biller.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _bouquets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              itemBuilder: (context, index) {
                final bouquet = _bouquets[index];
                final selected = index == _selectedBouquetIndex;
                return _BouquetCard(
                  bouquet: bouquet,
                  selected: selected,
                  priceLabel: bouquet.amount != null ? _money(bouquet.amount!) : '',
                  onTap: () => setState(() => _selectedBouquetIndex = index),
                );
              },
            ),
          const SizedBox(height: 16),
          const _InfoBanner(
            text: 'Cable subscriptions are activated instantly after PIN confirmation.',
            icon: Icons.live_tv_rounded,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final selectedBouquet = _selectedBouquetIndex >= 0 && _selectedBouquetIndex < _bouquets.length
        ? _bouquets[_selectedBouquetIndex]
        : null;

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
                title: 'Cable TV',
                subtitle: 'DSTV, GOtv, Startimes & more',
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
                amountLabel: selectedBouquet?.amount != null
                    ? _money(selectedBouquet!.amount!)
                    : null,
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
              child: AuthBackButton(onPressed: () => Navigator.of(context).pop()),
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

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
          Icon(icon, size: 18, color: AppColors.primary),
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
    this.amountLabel,
  });

  final double bottomPad;
  final bool enabled;
  final VoidCallback onPressed;
  final String? amountLabel;

  @override
  Widget build(BuildContext context) {
    final label = amountLabel != null && enabled ? 'Continue · $amountLabel' : 'Continue';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.9))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: AuthPrimaryButton(label: label, enabled: enabled, onPressed: onPressed),
    );
  }
}

// ─── Recent ──────────────────────────────────────────────────────────────────

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.recent, required this.style, required this.onTap});

  final _Recent recent;
  final ({Color color, String logoText, String? logoAsset}) style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shortCard = recent.cardno.length > 6
        ? '…${recent.cardno.substring(recent.cardno.length - 4)}'
        : recent.cardno;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 84,
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Badge(
                color: style.color,
                text: style.logoText,
                logoAsset: style.logoAsset,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                shortCard,
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
                recent.networkName,
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.color,
    required this.text,
    required this.size,
    this.logoAsset,
  });

  final Color color;
  final String text;
  final double size;
  final String? logoAsset;

  @override
  Widget build(BuildContext context) {
    final asset = logoAsset;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: asset != null ? Colors.white : color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: asset != null
          ? Padding(
              padding: EdgeInsets.all(size * 0.14),
              child: Image.asset(asset, fit: BoxFit.contain),
            )
          : Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: size * (text.length > 3 ? 0.22 : 0.34),
                ),
              ),
            ),
    );
  }
}

// ─── Biller select ───────────────────────────────────────────────────────────

class _BillerCard extends StatelessWidget {
  const _BillerCard({required this.biller, required this.selected, required this.onTap});

  final VtuNetwork biller;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(biller.name);
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
            color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border.withValues(alpha: 0.9),
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
                  _Badge(
                    color: style.color,
                    text: style.logoText,
                    logoAsset: style.logoAsset,
                    size: 40,
                  ),
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
                        child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                biller.name,
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

// ─── Fields ──────────────────────────────────────────────────────────────────

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.controller,
    required this.icon,
    required this.hintText,
    required this.onChanged,
    this.maxLength = 20,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
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
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 36),
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

// ─── Bouquet card ────────────────────────────────────────────────────────────

class _BouquetCard extends StatelessWidget {
  const _BouquetCard({
    required this.bouquet,
    required this.selected,
    required this.priceLabel,
    required this.onTap,
  });

  final BouquetOption bouquet;
  final bool selected;
  final String priceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border.withValues(alpha: 0.9),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bouquet.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              Text(
                priceLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Confirm sheet ───────────────────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.amount,
    required this.cardno,
    required this.customerName,
    required this.biller,
    required this.bouquetName,
    required this.balance,
    required this.onConfirm,
    required this.onClose,
  });

  final double amount;
  final String cardno;
  final String? customerName;
  final VtuNetwork biller;
  final String bouquetName;
  final double balance;
  final VoidCallback onConfirm;
  final VoidCallback onClose;

  String _money(double v) {
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final style = _styleFor(biller.name);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Confirm Subscription',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded, size: 24, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Badge(
            color: style.color,
            text: style.logoText,
            logoAsset: style.logoAsset,
            size: 52,
          ),
          const SizedBox(height: 12),
          Text(
            _money(amount),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          Text(bouquetName, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 22),
          _DetailRow(label: 'Smartcard number', value: cardno),
          if (customerName != null) ...[
            const SizedBox(height: 14),
            _DetailRow(label: 'Customer', value: customerName!),
          ],
          const SizedBox(height: 14),
          _DetailRow(label: 'Biller', value: biller.name),
          const SizedBox(height: 14),
          _DetailRow(label: 'Wallet Balance', value: _money(balance), bold: true),
          const SizedBox(height: 26),
          AuthPrimaryButton(label: 'Confirm Payment', onPressed: onConfirm),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Success ─────────────────────────────────────────────────────────────────

class _CableSuccessSheet extends StatelessWidget {
  const _CableSuccessSheet({
    required this.biller,
    required this.bouquetName,
    required this.cardno,
    required this.onDone,
    this.pending = false,
  });

  final String biller;
  final String bouquetName;
  final String cardno;
  final VoidCallback onDone;
  final bool pending;

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
            builder: (context, value, child) => Transform.scale(scale: value, child: child),
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
                      : [const Color(0xFFD1FAE5), const Color(0xFFECFDF5)],
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
                ? 'Your $biller $bouquetName subscription for $cardno is being '
                    'processed. We\'ll update your transaction history once '
                    'it\'s confirmed.'
                : 'You have successfully subscribed to $biller $bouquetName '
                    'for smartcard $cardno.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, height: 1.45, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 26),
          AuthPrimaryButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}
