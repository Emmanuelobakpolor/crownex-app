import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/vtu.dart';
import '../services/api_exception.dart';
import '../services/user_session.dart';
import '../services/vtu_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'airtime_pin_screen.dart';

class _Recent {
  const _Recent({required this.networkName, required this.phone});

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

/// Canonical carrier display order — only carriers actually present in the
/// PluginNG catalogue are shown.
const _carrierOrder = ['MTN', 'Airtel', 'Glo', '9mobile'];

/// PluginNG's "Data" category is a flat list of bundle subcategories per
/// carrier (e.g. "MTN SME", "MTN AWOOF", "AIRTEL DIRECT", "9MOBILE CG") —
/// not one entry per network. This groups them back under their carrier.
String? _carrierFor(String title) {
  final t = title.toLowerCase();
  if (t.contains('mtn')) return 'MTN';
  if (t.contains('airtel')) return 'Airtel';
  if (t.contains('glo')) return 'Glo';
  if (t.contains('9mobile')) return '9mobile';
  return null;
}

/// Strips the leading carrier name off a subcategory title so it reads as a
/// short plan-type tab label, e.g. "MTN SME" → "SME", "9MOBILE CG" → "CG".
String _typeLabel(String title) {
  final match = RegExp(
    r'^(MTN|AIRTEL|GLO|9MOBILE)\s*',
    caseSensitive: false,
  ).firstMatch(title);
  if (match == null) return title;
  final rest = title.substring(match.end).trim();
  return rest.isEmpty ? title : rest;
}

/// Buy Data — network, plan type, plan, PIN, processing, success.
class BuyDataScreen extends StatefulWidget {
  const BuyDataScreen({super.key});

  @override
  State<BuyDataScreen> createState() => _BuyDataScreenState();
}

class _BuyDataScreenState extends State<BuyDataScreen> {
  final _phoneController = TextEditingController();

  bool _loading = true;
  String? _loadError;
  Map<String, List<DataNetwork>> _byCarrier = const {};
  List<String> _carriers = const [];
  List<_Recent> _recents = const [];
  String? _selectedCarrier;
  DataNetwork? _selectedSubcategory;
  int _selectedPlanIndex = -1;
  VtuTransaction? _lastTx;

  List<DataNetwork> get _subcategories =>
      _byCarrier[_selectedCarrier] ?? const [];
  List<DataPlan> get _plans => _selectedSubcategory?.plans ?? const [];

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
        VtuService.instance.getTransactions(),
      ]);
      final catalogue = results[0] as VtuCatalogue;
      final transactions = results[1] as List<VtuTransaction>;

      final byCarrier = <String, List<DataNetwork>>{};
      for (final n in catalogue.data) {
        final carrier = _carrierFor(n.name);
        if (carrier == null) continue;
        byCarrier.putIfAbsent(carrier, () => []).add(n);
      }
      final carriers = [
        for (final c in _carrierOrder)
          if (byCarrier.containsKey(c)) c,
      ];

      final recents = <_Recent>[];
      final seenPhones = <String>{};
      for (final tx in transactions) {
        if (tx.service != 'data' || !seenPhones.add(tx.phone)) continue;
        recents.add(_Recent(networkName: tx.network, phone: tx.phone));
        if (recents.length >= 4) break;
      }

      if (!mounted) return;
      final firstCarrier = carriers.isNotEmpty ? carriers.first : null;
      final firstSub =
          firstCarrier != null ? byCarrier[firstCarrier]!.first : null;
      setState(() {
        _byCarrier = byCarrier;
        _carriers = carriers;
        _recents = recents;
        _selectedCarrier = firstCarrier;
        _selectedSubcategory = firstSub;
        _selectedPlanIndex = firstSub?.plans.isNotEmpty == true ? 0 : -1;
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
        _loadError = 'Could not load data plans. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return phone.length >= 10 &&
        _selectedSubcategory != null &&
        _selectedPlanIndex >= 0 &&
        _selectedPlanIndex < _plans.length;
  }

  DataPlan? get _selectedPlan {
    if (_selectedPlanIndex < 0 || _selectedPlanIndex >= _plans.length) {
      return null;
    }
    return _plans[_selectedPlanIndex];
  }

  void _selectRecent(_Recent recent) {
    if (_carriers.isEmpty) return;
    DataNetwork? match;
    String? matchCarrier;
    for (final entry in _byCarrier.entries) {
      for (final sub in entry.value) {
        if (sub.name.toLowerCase() == recent.networkName.toLowerCase()) {
          match = sub;
          matchCarrier = entry.key;
          break;
        }
      }
      if (match != null) break;
    }
    setState(() {
      _phoneController.text = recent.phone;
      if (match != null) {
        _selectedCarrier = matchCarrier;
        _selectedSubcategory = match;
        _selectedPlanIndex = match.plans.isNotEmpty ? 0 : -1;
      }
    });
  }

  void _selectCarrier(String carrier) {
    final subs = _byCarrier[carrier] ?? const [];
    setState(() {
      _selectedCarrier = carrier;
      _selectedSubcategory = subs.isNotEmpty ? subs.first : null;
      _selectedPlanIndex =
          subs.isNotEmpty && subs.first.plans.isNotEmpty ? 0 : -1;
    });
  }

  void _selectSubcategory(DataNetwork sub) {
    setState(() {
      _selectedSubcategory = sub;
      _selectedPlanIndex = sub.plans.isNotEmpty ? 0 : -1;
    });
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

  String _moneyShort(double v) {
    if (v == v.roundToDouble()) {
      final s = v.round().toString();
      final buf = StringBuffer('₦');
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return buf.toString();
    }
    return _money(v);
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    final subcategory = _selectedSubcategory!;
    final plan = _plans[_selectedPlanIndex];
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');

    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AirtimePinScreen(
          amount: plan.amount,
          phone: phone,
          networkName: subcategory.name,
          onSubmit: (pin) async {
            _lastTx = await VtuService.instance.buyData(
              subcategoryId: subcategory.subcategoryId,
              network: subcategory.name,
              planId: plan.planId,
              phone: phone,
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
        builder: (ctx) => _DataSuccessSheet(
          networkName: subcategory.name,
          planLabel: plan.planId,
          phone: phone,
          amount: plan.amount,
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
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recents.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final r = _recents[i];
                  return _RecentChip(
                    recent: r,
                    onTap: () => _selectRecent(r),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
          ],
          const _SectionLabel('Phone number'),
          const SizedBox(height: 10),
          _PhoneField(
            controller: _phoneController,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Network'),
          const SizedBox(height: 12),
          _CarrierRow(
            carriers: _carriers,
            selected: _selectedCarrier,
            onSelect: _selectCarrier,
          ),
          if (_subcategories.length > 1) ...[
            const SizedBox(height: 22),
            const _SectionLabel('Plan type'),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _subcategories.map((sub) {
                  final selected =
                      sub.subcategoryId == _selectedSubcategory?.subcategoryId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PlanTypeChip(
                      label: _typeLabel(sub.name),
                      selected: selected,
                      onTap: () => _selectSubcategory(sub),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(child: _SectionLabel('Choose a plan')),
              if (_plans.isNotEmpty)
                Text(
                  '${_plans.length} options',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_plans.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.9),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 32,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No data plans available for this network right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_plans.length, (i) {
              final plan = _plans[i];
              final selected = i == _selectedPlanIndex;
              return Padding(
                padding: EdgeInsets.only(bottom: i < _plans.length - 1 ? 10 : 0),
                child: _PlanTile(
                  label: plan.planId,
                  selected: selected,
                  priceLabel: _moneyShort(plan.amount),
                  onTap: () => setState(() => _selectedPlanIndex = i),
                ),
              );
            }),
          const SizedBox(height: 16),
          const _InfoBanner(
            text:
                'Data plans are activated instantly after PIN confirmation. '
                'Validity depends on the selected bundle.',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final plan = _selectedPlan;

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
                title: 'Buy Data',
                subtitle: 'Choose a plan for any network',
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
                amountLabel: plan != null ? _moneyShort(plan.amount) : null,
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
            Icons.wifi_tethering_rounded,
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
    this.amountLabel,
  });

  final double bottomPad;
  final bool enabled;
  final VoidCallback onPressed;
  final String? amountLabel;

  @override
  Widget build(BuildContext context) {
    final label = amountLabel != null && enabled
        ? 'Continue · $amountLabel'
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
  const _RecentChip({required this.recent, required this.onTap});

  final _Recent recent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(recent.networkName);
    final shortPhone = recent.phone.length > 7
        ? '…${recent.phone.substring(recent.phone.length - 4)}'
        : recent.phone;

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
              _Logo(
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

class _Logo extends StatelessWidget {
  const _Logo({
    required this.color,
    required this.logoText,
    required this.logoTextColor,
    required this.size,
    this.logoAsset,
  });

  final Color color;
  final String logoText;
  final Color logoTextColor;
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
                  fontSize: size * (logoText.length > 2 ? 0.26 : 0.36),
                ),
              ),
            ),
    );
  }
}

// ─── Phone ───────────────────────────────────────────────────────────────────

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

// ─── Carrier select ──────────────────────────────────────────────────────────

class _CarrierRow extends StatelessWidget {
  const _CarrierRow({
    required this.carriers,
    required this.selected,
    required this.onSelect,
  });

  final List<String> carriers;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (carriers.isEmpty) {
      return const Text(
        'No networks available',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: carriers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final carrier = carriers[i];
          return _CarrierCard(
            carrierName: carrier,
            selected: carrier == selected,
            onTap: () => onSelect(carrier),
          );
        },
      ),
    );
  }
}

class _CarrierCard extends StatelessWidget {
  const _CarrierCard({
    required this.carrierName,
    required this.selected,
    required this.onTap,
  });

  final String carrierName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(carrierName);

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
                  _Logo(
                    color: style.color,
                    logoText: style.logoText,
                    logoTextColor: style.logoTextColor,
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
                carrierName,
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

// ─── Plan type chips ─────────────────────────────────────────────────────────

class _PlanTypeChip extends StatelessWidget {
  const _PlanTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Plan tile ───────────────────────────────────────────────────────────────

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.label,
    required this.selected,
    required this.priceLabel,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final String priceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.05)
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
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.dotInactive,
                    width: selected ? 0 : 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selected ? 'Selected plan' : 'Tap to select',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.75)
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  priceLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Success ─────────────────────────────────────────────────────────────────

class _DataSuccessSheet extends StatelessWidget {
  const _DataSuccessSheet({
    required this.networkName,
    required this.planLabel,
    required this.phone,
    required this.amount,
    required this.onDone,
    this.pending = false,
  });

  final String networkName;
  final String planLabel;
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
                ? 'Your $networkName $planLabel purchase for $phone is being '
                    'processed. We\'ll update your transaction history once '
                    'it\'s confirmed.'
                : 'You successfully purchased $planLabel ($networkName) for '
                    '$phone · ${_money(amount)}.',
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
