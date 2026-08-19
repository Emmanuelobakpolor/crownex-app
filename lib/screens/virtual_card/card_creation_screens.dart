import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/card.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/card_service.dart';
import '../../services/user_session.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth_widgets.dart';
import 'virtual_card_controller.dart';
import 'virtual_card_widgets.dart';

// ─── Create / confirm PIN ────────────────────────────────────────────────────

/// Collects (or reuses) the account-wide transaction PIN, then requests
/// the real Bitnob card. If the user already has a transaction PIN set,
/// [existingPin] is never used as a "new PIN" — instead the single entry
/// is submitted directly as the PIN check for card creation. Only users
/// without a PIN yet go through the enter-then-confirm two-step (which
/// also calls AuthService.setTransactionPin to actually set it).
class CardPinScreen extends StatefulWidget {
  const CardPinScreen({
    super.key,
    required this.controller,
    required this.hasExistingPin,
    this.existingPin,
  });

  final VirtualCardController controller;
  final bool hasExistingPin;
  final String? existingPin;

  bool get isConfirm => existingPin != null;

  @override
  State<CardPinScreen> createState() => _CardPinScreenState();
}

class _CardPinScreenState extends State<CardPinScreen> {
  String _pin = '';
  String? _error;
  bool _submitting = false;

  void _digit(String d) {
    if (_pin.length >= 4 || _submitting) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) {
      Future<void>.delayed(const Duration(milliseconds: 120), _submit);
    }
  }

  void _backspace() {
    if (_pin.isEmpty || _submitting) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_pin.length != 4 || !mounted) return;

    // User already has a transaction PIN — this single entry IS the PIN,
    // submit it straight to card creation.
    if (widget.hasExistingPin) {
      await _requestCard(_pin);
      return;
    }

    // No PIN yet — first entry, push the confirm step.
    if (!widget.isConfirm) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CardPinScreen(
            controller: widget.controller,
            hasExistingPin: false,
            existingPin: _pin,
          ),
        ),
      );
      if (mounted) setState(() => _pin = '');
      return;
    }

    // Confirm step — PINs must match, then actually set it before creating the card.
    if (_pin != widget.existingPin) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _pin = '';
      });
      return;
    }

    setState(() => _submitting = true);
    try {
      final user = await AuthService.instance.setTransactionPin(
        pin: _pin,
        pinConfirm: _pin,
      );
      if (!mounted) return;
      context.read<UserSession>().setUser(user);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
      return;
    }
    await _requestCard(_pin);
  }

  Future<void> _requestCard(String pin) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.controller.requestCard(pin: pin);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CardPreparingScreen(controller: widget.controller),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _pin = '';
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      'Cards',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: AuthBackButton(),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Text(
                    widget.hasExistingPin ? 'Enter your pin' : 'Create your pin',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.hasExistingPin
                        ? 'Enter your transaction PIN to request your card'
                        : widget.isConfirm
                        ? 'Confirm your 4-digit pin'
                        : 'Set a 4-digit pin for your virtual card',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < _pin.length;
                      return Container(
                        margin: EdgeInsets.only(right: i < 3 ? 12 : 0),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: filled
                            ? const Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: SizedBox(width: 10, height: 10),
                                ),
                              )
                            : null,
                      );
                    }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const Spacer(flex: 3),
                ],
              ),
            ),
            _Keypad(
              onDigit: _digit,
              onBackspace: _backspace,
              bottomInset: bottom,
            ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.bottomInset,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];
    return Container(
      color: const Color(0xFFD1D3D9),
      padding: EdgeInsets.fromLTRB(4, 6, 4, 6 + bottomInset),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: row.map((k) {
                if (k.isEmpty) {
                  return const Expanded(child: SizedBox(height: 48));
                }
                if (k == 'back') {
                  return Expanded(
                    child: _Key(
                      onTap: onBackspace,
                      child: const Icon(Icons.backspace_outlined, size: 22),
                    ),
                  );
                }
                return Expanded(
                  child: _Key(
                    onTap: () => onDigit(k),
                    child: Text(k, style: const TextStyle(fontSize: 24)),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(height: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}

// ─── Preparing ───────────────────────────────────────────────────────────────

class CardPreparingScreen extends StatefulWidget {
  const CardPreparingScreen({super.key, required this.controller});

  final VirtualCardController controller;

  @override
  State<CardPreparingScreen> createState() => _CardPreparingScreenState();
}

class _CardPreparingScreenState extends State<CardPreparingScreen> {
  static const _pollInterval = Duration(seconds: 3);
  static const _timeout = Duration(seconds: 30);

  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    _poll(DateTime.now());
  }

  Future<void> _poll(DateTime startedAt) async {
    final card = await widget.controller.syncCardFromBackend();
    if (!mounted) return;

    if (card != null && !card.isProvisioning) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CardCreationSuccessScreen(controller: widget.controller),
        ),
      );
      return;
    }

    if (DateTime.now().difference(startedAt) >= _timeout) {
      setState(() => _timedOut = true);
      return;
    }

    await Future<void>.delayed(_pollInterval);
    if (mounted) _poll(startedAt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Cards',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 28),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: VirtualCardVisual(last4: '78'),
            ),
            const SizedBox(height: 36),
            Text(
              _timedOut ? 'Still preparing your card' : 'Preparing your Card',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _timedOut
                    ? 'This is taking longer than usual. You can check back '
                          'from the Cards tab shortly.'
                    : 'This will take some couple of minutes',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 36),
            if (_timedOut)
              AuthPrimaryButton(
                label: 'Back to cards',
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              )
            else
              const Icon(
                Icons.hourglass_top_rounded,
                size: 56,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Success ─────────────────────────────────────────────────────────────────

class CardCreationSuccessScreen extends StatelessWidget {
  const CardCreationSuccessScreen({super.key, required this.controller});

  final VirtualCardController controller;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 12 + bottom),
          child: Column(
            children: [
              const Text(
                'Cards',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 28),
              const VirtualCardVisual(last4: '78'),
              const SizedBox(height: 36),
              const Text(
                'Card Creation Successful',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enjoy your seamless payment transactions',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2.5),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const Spacer(),
              AuthPrimaryButton(
                label: 'Continue to card',
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Active card dashboard (used inside tab) ─────────────────────────────────

class CardDashboard extends StatefulWidget {
  const CardDashboard({super.key, required this.controller});

  final VirtualCardController controller;

  @override
  State<CardDashboard> createState() => _CardDashboardState();
}

class _CardDashboardState extends State<CardDashboard> {
  List<CardTransactionEntry>? _transactions;
  bool _loading = true;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final txs = await CardService.instance.getTransactions();
      if (mounted) setState(() => _transactions = txs);
    } catch (_) {
      // Best-effort — dashboard still shows the card even if history fails.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshCard() async {
    await widget.controller.syncCardFromBackend();
    await _load();
  }

  Future<void> _openFundSheet({required bool isWithdraw}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FundWithdrawSheet(isWithdraw: isWithdraw),
    );
    if (result == true) await _refreshCard();
  }

  Future<void> _toggleFreeze() async {
    final card = widget.controller.card;
    if (card == null || _acting) return;
    setState(() => _acting = true);
    try {
      if (card.isFrozen) {
        await CardService.instance.unfreezeCard();
      } else {
        await CardService.instance.freezeCard();
      }
      await widget.controller.syncCardFromBackend();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.controller.card;

    return RefreshIndicator(
      onRefresh: _refreshCard,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 12, 0, 0),
              child: Center(
                child: Text(
                  'Cards',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VirtualCardVisual(
                    last4: card?.maskedPan.isNotEmpty == true
                        ? card!.maskedPan.substring(card.maskedPan.length - 4)
                        : '78',
                    balanceDisplay: card?.balanceDisplay,
                  ),
                  if (card?.isFrozen == true) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Card is frozen — unfreeze to resume spending.',
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _ActionChip(
                        icon: Icons.add_card_outlined,
                        label: 'Top up',
                        onTap: _acting ? () {} : () => _openFundSheet(isWithdraw: false),
                      ),
                      const SizedBox(width: 10),
                      _ActionChip(
                        icon: Icons.outbox_outlined,
                        label: 'Withdraw',
                        onTap: _acting ? () {} : () => _openFundSheet(isWithdraw: true),
                      ),
                      const SizedBox(width: 10),
                      _ActionChip(
                        icon: card?.isFrozen == true
                            ? Icons.ac_unit_outlined
                            : Icons.ac_unit_rounded,
                        label: card?.isFrozen == true ? 'Unfreeze' : 'Freeze',
                        onTap: _acting ? () {} : _toggleFreeze,
                      ),
                      const SizedBox(width: 10),
                      _ActionChip(
                        icon: Icons.more_horiz_rounded,
                        label: 'More',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Transactions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CardTransactionsScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: _loading
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                : (_transactions == null || _transactions!.isEmpty)
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No transactions yet',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _TxRow.fromEntry(_transactions![i]),
                      childCount: _transactions!.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: const Color(0xFFF3F4F8),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({
    required this.title,
    required this.time,
    required this.amount,
    required this.status,
    required this.incoming,
  });

  factory _TxRow.fromEntry(CardTransactionEntry entry) {
    final hour = entry.createdAt.hour % 12 == 0 ? 12 : entry.createdAt.hour % 12;
    final minute = entry.createdAt.minute.toString().padLeft(2, '0');
    final period = entry.createdAt.hour >= 12 ? 'pm' : 'am';
    return _TxRow(
      title: entry.isFunding ? 'Card Top Up' : 'Withdrawal',
      time: '$hour:$minute $period',
      amount: '${entry.amountDisplay} USD',
      status: switch (entry.status) {
        'completed' => 'successful',
        'failed' => 'declined',
        _ => 'pending',
      },
      incoming: entry.isFunding,
    );
  }

  final String title;
  final String time;
  final String amount;
  final String status;
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    Color pillColor;
    Color pillBg;
    switch (status) {
      case 'pending':
        pillColor = const Color(0xFFB45309);
        pillBg = const Color(0xFFFEF3C7);
      case 'declined':
        pillColor = const Color(0xFFDC2626);
        pillBg = const Color(0xFFFEE2E2);
      default:
        pillColor = const Color(0xFF16A34A);
        pillBg = const Color(0xFFDCFCE7);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EEFF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              incoming
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              StatusPill(label: status, color: pillColor, bg: pillBg),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Full transactions ───────────────────────────────────────────────────────

class CardTransactionsScreen extends StatefulWidget {
  const CardTransactionsScreen({super.key});

  @override
  State<CardTransactionsScreen> createState() => _CardTransactionsScreenState();
}

class _CardTransactionsScreenState extends State<CardTransactionsScreen> {
  int _tab = 0; // 0 all, 1 received (funding), 2 sent (withdrawal)
  List<CardTransactionEntry>? _transactions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final txs = await CardService.instance.getTransactions();
      if (mounted) setState(() => _transactions = txs);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load transactions.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _transactions
        ?.where((t) {
          if (_tab == 1) return t.isFunding;
          if (_tab == 2) return !t.isFunding;
          return true;
        })
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            CardFlowHeader(
              title: 'Card Transactions',
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _TabLabel(
                    label: 'All',
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  const SizedBox(width: 28),
                  _TabLabel(
                    label: 'Received',
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  const SizedBox(width: 28),
                  _TabLabel(
                    label: 'Sent',
                    selected: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                  : filtered == null
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? const Center(
                      child: Text('No transactions', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _TxRow.fromEntry(filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 2.5,
            width: 28,
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

// ─── Fund / withdraw sheet ────────────────────────────────────────────────────

class _FundWithdrawSheet extends StatefulWidget {
  const _FundWithdrawSheet({required this.isWithdraw});

  final bool isWithdraw;

  @override
  State<_FundWithdrawSheet> createState() => _FundWithdrawSheetState();
}

class _FundWithdrawSheetState extends State<_FundWithdrawSheet> {
  final _amount = TextEditingController();
  final _pin = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _pin.dispose();
    super.dispose();
  }

  bool get _valid {
    final amount = double.tryParse(_amount.text);
    return amount != null && amount > 0 && _pin.text.length == 4;
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text);
    if (amount == null || !mounted) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (widget.isWithdraw) {
        await CardService.instance.withdrawCard(ngnAmount: amount, pin: _pin.text);
      } else {
        await CardService.instance.fundCard(ngnAmount: amount, pin: _pin.text);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final title = widget.isWithdraw ? 'Withdraw from card' : 'Top up card';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: const Icon(Icons.close_rounded, size: 24, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.isWithdraw
                    ? 'Move USD from your card back to your NGN wallet.'
                    : 'Fund your card from your NGN wallet balance.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              const VerifyFieldLabel('Amount (NGN)'),
              VerifyTextField(
                controller: _amount,
                hint: '5000',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const VerifyFieldLabel('Transaction PIN'),
              VerifyTextField(
                controller: _pin,
                hint: '••••',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              VerifySubmitButton(
                enabled: _valid && !_submitting,
                label: _submitting ? 'Processing…' : (widget.isWithdraw ? 'Withdraw' : 'Fund card'),
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
