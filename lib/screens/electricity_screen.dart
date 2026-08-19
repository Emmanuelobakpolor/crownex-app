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
  const _Recent({required this.billerName, required this.meter});

  final String billerName;
  final String meter;
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

/// Electricity — biller, meter verify, variation type, amount, PIN, success.
class ElectricityScreen extends StatefulWidget {
  const ElectricityScreen({super.key});

  @override
  State<ElectricityScreen> createState() => _ElectricityScreenState();
}

class _ElectricityScreenState extends State<ElectricityScreen> {
  final _phoneController = TextEditingController();
  final _meterController = TextEditingController();
  final _amountController = TextEditingController();
  final _amountFocus = FocusNode();

  bool _loading = true;
  String? _loadError;
  double _ngnBalance = 0;
  List<ElectricityBiller> _billers = const [];
  List<_Recent> _recents = const [];
  ElectricityBiller? _selectedBiller;

  bool _variationsLoading = false;
  String? _variationError;
  List<BouquetOption> _variations = const [];
  BouquetOption? _selectedVariation;

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
    _meterController.dispose();
    _amountController.dispose();
    _amountFocus.dispose();
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
      final seenMeters = <String>{};
      for (final tx in transactions) {
        if (tx.service != 'electricity' || !seenMeters.add(tx.cardNumber)) continue;
        recents.add(_Recent(billerName: tx.network, meter: tx.cardNumber));
        if (recents.length >= 4) break;
      }

      if (!mounted) return;
      setState(() {
        _billers = catalogue.electricity;
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

  Future<void> _selectBiller(ElectricityBiller biller) async {
    setState(() {
      _selectedBiller = biller;
      _variations = const [];
      _selectedVariation = null;
      _variationsLoading = true;
      _variationError = null;
      _customerName = null;
      _verifyError = null;
    });
    try {
      final variations = await VtuService.instance.getElectricityVariations(biller.name);
      if (!mounted) return;
      setState(() {
        _variations = variations;
        _selectedVariation = variations.isNotEmpty ? variations.first : null;
        _variationsLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _variationError = e.message;
        _variationsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _variationError = 'Could not load payment types for this biller.';
        _variationsLoading = false;
      });
    }
    _maybeVerify();
  }

  void _selectVariation(BouquetOption variation) {
    setState(() {
      _selectedVariation = variation;
      _customerName = null;
      _verifyError = null;
    });
    _maybeVerify();
  }

  void _onMeterChanged(String value) {
    setState(() {
      _customerName = null;
      _verifyError = null;
    });
    _verifyDebounce?.cancel();
    _verifyDebounce = Timer(const Duration(milliseconds: 500), _maybeVerify);
  }

  void _maybeVerify() {
    final biller = _selectedBiller;
    final variation = _selectedVariation;
    final meter = _meterController.text.trim();
    if (biller == null || variation == null || meter.length < 6) return;
    _verifyMeter(biller, variation, meter);
  }

  Future<void> _verifyMeter(
    ElectricityBiller biller,
    BouquetOption variation,
    String meter,
  ) async {
    setState(() => _verifying = true);
    try {
      final data = await VtuService.instance.verifyMeter(
        network: biller.name,
        cardno: meter,
        meterType: variation.variationCode,
      );
      if (!mounted) return;
      final name = _extractCustomerName(data);
      setState(() {
        _customerName = name;
        _verifyError = name == null ? 'Could not verify this meter number.' : null;
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
        _verifyError = 'Could not verify this meter number.';
        _verifying = false;
      });
    }
  }

  double? get _amount {
    final raw = _amountController.text.replaceAll(',', '').trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  String? get _amountHint {
    final amount = _amount;
    if (amount == null) return null;
    if (amount < 500) return 'Minimum amount is ₦500';
    if (amount > 100000) return 'Maximum amount is ₦100,000';
    if (amount > _ngnBalance) return 'Exceeds your wallet balance';
    return null;
  }

  bool get _canContinue {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final meter = _meterController.text.trim();
    final amount = _amount;
    return _selectedBiller != null &&
        _selectedVariation != null &&
        phone.length >= 10 &&
        meter.length >= 6 &&
        amount != null &&
        amount >= 500 &&
        amount <= 100000;
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
    final biller = _selectedBiller!;
    final variation = _selectedVariation!;
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final meter = _meterController.text.trim();
    final amount = _amount!;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _ConfirmSheet(
        amount: amount,
        meter: meter,
        customerName: _customerName,
        biller: biller,
        variationName: variation.name,
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
          networkName: '${biller.name} (${variation.name})',
          onSubmit: (pin) async {
            _lastTx = await VtuService.instance.buyElectricity(
              subcategoryId: biller.subcategoryId,
              network: biller.name,
              serviceId: biller.serviceId,
              phone: phone,
              cardno: meter,
              variationCode: variation.variationCode,
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
        builder: (ctx) => _ElectricitySuccessSheet(
          biller: biller.name,
          meter: meter,
          amount: amount,
          providerMessage: _lastTx?.providerResponse ?? '',
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

    final amountHint = _amountHint;

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
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recents.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final r = _recents[i];
                  return _RecentChip(
                    recent: r,
                    onTap: () {
                      final match = _billers.firstWhere(
                        (b) => b.name.toLowerCase() == r.billerName.toLowerCase(),
                        orElse: () => _billers.first,
                      );
                      _meterController.text = r.meter;
                      _onMeterChanged(r.meter);
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
          const SizedBox(height: 10),
          _SelectField(
            value: _selectedBiller?.name,
            placeholder: _billers.isEmpty ? 'No billers available' : 'Select a biller',
            onTap: _billers.isEmpty ? null : _pickBiller,
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Payment type'),
          const SizedBox(height: 10),
          if (_variationsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.primary),
                ),
              ),
            )
          else if (_variationError != null)
            Text(_variationError!, style: const TextStyle(color: AppColors.textSecondary))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _variations.map((v) {
                final selected = v.variationCode == _selectedVariation?.variationCode;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _selectVariation(v),
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: selected ? AppColors.primary : AppColors.border,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        v.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
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
          const _SectionLabel('Meter number'),
          const SizedBox(height: 10),
          _LabeledField(
            controller: _meterController,
            icon: Icons.speed_rounded,
            hintText: 'Enter meter number',
            maxLength: 20,
            keyboardType: TextInputType.text,
            onChanged: _onMeterChanged,
          ),
          if (_verifying) ...[
            const SizedBox(height: 8),
            const Text('Verifying…', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
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
            Text(_verifyError!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626))),
          ],
          const SizedBox(height: 22),
          const _SectionLabel('Amount'),
          const SizedBox(height: 12),
          _AmountCard(
            controller: _amountController,
            focusNode: _amountFocus,
            amountHint: amountHint,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const _InfoBanner(
            text: 'Your token will be delivered instantly after PIN confirmation.',
            icon: Icons.bolt_rounded,
          ),
        ],
      ),
    );
  }

  Future<void> _pickBiller() async {
    final selected = await showModalBottomSheet<ElectricityBiller>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        final bottom = MediaQuery.paddingOf(ctx).bottom;
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.6),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(8, 12, 8, 12 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Select Biller',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: const Icon(Icons.close_rounded, size: 22, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _billers.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Color(0xFFEEF0F4)),
                  itemBuilder: (context, i) {
                    final biller = _billers[i];
                    final selected = biller.subcategoryId == _selectedBiller?.subcategoryId;
                    return ListTile(
                      title: Text(
                        biller.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 22)
                          : null,
                      onTap: () => Navigator.of(ctx).pop(biller),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) _selectBiller(selected);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const _ScreenHeader(
                title: 'Electricity',
                subtitle: 'Pay any DISCO across Nigeria',
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
                amountLabel: _amount != null ? _moneyShort(_amount!) : null,
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
  const _RecentChip({required this.recent, required this.onTap});

  final _Recent recent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shortMeter =
        recent.meter.length > 6 ? '…${recent.meter.substring(recent.meter.length - 4)}' : recent.meter;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                recent.billerName,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                shortMeter,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Select field ────────────────────────────────────────────────────────────

class _SelectField extends StatelessWidget {
  const _SelectField({required this.value, required this.placeholder, required this.onTap});

  final String? value;
  final String placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? value! : placeholder,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    color: hasValue ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 24, color: AppColors.textSecondary),
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
    this.keyboardType = TextInputType.number,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int maxLength;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      inputFormatters: [
        if (keyboardType == TextInputType.number) FilteringTextInputFormatter.digitsOnly,
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChanged: onChanged,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -1,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted.withValues(alpha: 0.4),
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(right: 2, top: 4),
                child: Text(
                  '₦',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              amountHint ?? 'Minimum ₦500 · Token delivered instantly',
              key: ValueKey(amountHint ?? 'default'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: amountHint != null ? const Color(0xFFDC2626) : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Confirm sheet ───────────────────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.amount,
    required this.meter,
    required this.customerName,
    required this.biller,
    required this.variationName,
    required this.balance,
    required this.onConfirm,
    required this.onClose,
  });

  final double amount;
  final String meter;
  final String? customerName;
  final ElectricityBiller biller;
  final String variationName;
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
                  'Confirm Payment',
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
          const SizedBox(height: 24),
          Container(
            width: 56,
            height: 56,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bolt_rounded, size: 28, color: Colors.white),
          ),
          Text(
            _money(amount),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 22),
          _DetailRow(label: 'Meter number', value: meter),
          if (customerName != null) ...[
            const SizedBox(height: 14),
            _DetailRow(label: 'Customer', value: customerName!),
          ],
          const SizedBox(height: 14),
          _DetailRow(label: 'Biller', value: biller.name),
          const SizedBox(height: 14),
          _DetailRow(label: 'Payment type', value: variationName),
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

class _ElectricitySuccessSheet extends StatelessWidget {
  const _ElectricitySuccessSheet({
    required this.biller,
    required this.meter,
    required this.amount,
    required this.providerMessage,
    required this.onDone,
    this.pending = false,
  });

  final String biller;
  final String meter;
  final double amount;
  final String providerMessage;
  final VoidCallback onDone;
  final bool pending;

  Future<void> _copyMessage(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: providerMessage));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

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
            pending ? 'Payment Submitted' : 'Payment Successful',
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
                ? 'Your ${_money(amount)} payment to $biller for meter $meter is '
                    'being processed. We\'ll update your transaction history '
                    'once it\'s confirmed.'
                : 'You have successfully paid ${_money(amount)} to $biller for '
                    'meter $meter.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, height: 1.45, color: AppColors.textSecondary),
          ),
          if (!pending && providerMessage.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      providerMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _copyMessage(context),
                    child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          AuthPrimaryButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}
