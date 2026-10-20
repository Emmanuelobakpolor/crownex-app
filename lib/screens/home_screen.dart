import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/app_transaction.dart';
import '../services/app_transactions_service.dart';
import '../services/user_session.dart';
import '../services/wallet_service.dart';
import '../theme/app_colors.dart';
import '../widgets/kyc_banner.dart';
import '../widgets/kyc_guard.dart';
import '../widgets/user_avatar.dart';
import 'buy_airtime_screen.dart';
import 'buy_data_screen.dart';
import 'cable_tv_screen.dart';
import 'crypto_hub_screen.dart';
import 'deposit_menu_screen.dart';
import 'electricity_screen.dart';
import 'gift_card_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';
import 'top_up_withdraw_menu_screen.dart';
import 'transaction_details_screen.dart';
import 'transaction_history_screen.dart';
import 'virtual_card/virtual_card_controller.dart';
import 'virtual_card/virtual_card_tab.dart';
import 'withdraw_menu_screen.dart';

/// Main app home after signup / sign-in.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.fullName = 'JohnOlamide'});

  final String fullName;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;
  final VirtualCardController _cardController = VirtualCardController();

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  void _openVirtualCardTab() {
    setState(() => _tabIndex = 2);
  }

  void _openSettingsTab() {
    setState(() => _tabIndex = 3);
  }

  void _openHomeTab() {
    setState(() => _tabIndex = 0);
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
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
          bottom: false,
          child: IndexedStack(
            index: _tabIndex,
            children: [
              _HomeTab(
                fallbackFullName: widget.fullName,
                greeting: _greeting,
                onOpenVirtualCard: _openVirtualCardTab,
                onOpenSettings: _openSettingsTab,
              ),
              ServicesScreen(onOpenVirtualCard: _openVirtualCardTab),
              VirtualCardTab(
                controller: _cardController,
                onClose: _openHomeTab,
              ),
              SettingsScreen(fullName: widget.fullName),
            ],
          ),
        ),
        bottomNavigationBar: _HomeBottomNav(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
        ),
      ),
    );
  }
}

String _formatBalance(double v) {
  final s = v.toStringAsFixed(2);
  final parts = s.split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '${buf.toString()}.${parts[1]}';
}

/// Collapses a full name into a compact "FirstLast" greeting form.
String _formatDisplayName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts.first.isNotEmpty) {
    return '${parts.first}${parts.last}';
  }
  return parts.isEmpty || parts.first.isEmpty ? 'User' : parts.first;
}

// ─── Home tab content ────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.fallbackFullName,
    required this.greeting,
    this.onOpenVirtualCard,
    this.onOpenSettings,
  });

  final String fallbackFullName;
  final String greeting;
  final VoidCallback? onOpenVirtualCard;
  final VoidCallback? onOpenSettings;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with RouteAware {
  final _wallet = WalletService.instance;

  bool _loading = true;
  bool _balanceVisible = true;
  double _balance = 0;
  List<AppTransaction> _recent = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute<void>);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when a route pushed on top of Home (airtime, data, electricity,
  /// crypto, etc.) is popped back to Home — refreshes the balance so a
  /// completed transaction shows up immediately instead of only after the
  /// app is restarted.
  @override
  void didPopNext() {
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final session = context.read<UserSession>();
    try {
      final wallet = await _wallet.getWallet();
      final transactions = await AppTransactionsService.instance.getAll();
      if (!session.kycChecked) await session.refreshKycStatus();
      if (!mounted) return;
      setState(() {
        _balance = wallet.ngnBalance;
        _recent = transactions.take(3).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openDeposit() async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const KycGuard(
          featureName: 'Fiat deposits',
          featureReason:
              'To keep your funds safe and comply with regulations, we '
              'need to verify your identity before you can deposit money.',
          child: DepositMenuScreen(),
        ),
      ),
    );
    if (refreshed == true) _load();
  }

  Future<void> _openWithdraw() async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const WithdrawMenuScreen()),
    );
    if (refreshed == true) _load();
  }

  Future<void> _openMenu() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TopUpWithdrawMenuScreen()),
    );
    _load();
  }

  void _openHistory() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const TransactionHistoryScreen()),
    );
  }

  void _toggleBalanceVisible() {
    setState(() => _balanceVisible = !_balanceVisible);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GreetingHeader(
                    fallbackFullName: widget.fallbackFullName,
                    greeting: widget.greeting,
                    onOpenSettings: widget.onOpenSettings,
                  ),
                  const SizedBox(height: 20),
                  _BalanceCard(
                    balance: _balance,
                    loading: _loading,
                    balanceVisible: _balanceVisible,
                    onToggleVisible: _toggleBalanceVisible,
                    onDeposit: _openDeposit,
                    onWithdraw: _openWithdraw,
                    onMore: _openMenu,
                  ),
                  if (!_loading)
                    KycBanner(
                      status: context.watch<UserSession>().kycStatus,
                      onVerified: () =>
                          context.read<UserSession>().refreshKycStatus(),
                    ),
                  const SizedBox(height: 20),
                  _ServicesGrid(onOpenVirtualCard: widget.onOpenVirtualCard),
                  const SizedBox(height: 24),
                  _RecentTransactionsHeader(onSeeAll: _openHistory),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                _loading
                    ? const []
                    : _recent.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No transactions yet',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ]
                    : [
                        for (final tx in _recent) ...[
                          _NgnTransactionTile(tx: tx),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 68),
                      ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Greeting ────────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.fallbackFullName,
    required this.greeting,
    this.onOpenSettings,
  });

  final String fallbackFullName;
  final String greeting;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserSession>().user;
    final displayName = _formatDisplayName(user?.fullName ?? fallbackFullName);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          UserAvatar(
            size: 50,
            profilePictureUrl: user?.profilePicture,
            fallbackName: displayName,
            borderWidth: 2.5,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $displayName,',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenSettings,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.settings_outlined,
                  size: 21,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Balance card ────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.balance,
    required this.loading,
    required this.balanceVisible,
    required this.onToggleVisible,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onMore,
  });

  final double balance;
  final bool loading;
  final bool balanceVisible;
  final VoidCallback onToggleVisible;
  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A3DFF), Color(0xFF041B6B), Color(0xFF020B2E)],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF041B6B).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'All Accounts',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB8C4E8),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '•',
                  style: TextStyle(fontSize: 13, color: Color(0xFFB8C4E8)),
                ),
              ),
              Text(
                'NGN Balance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB8C4E8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  loading
                      ? 'N••••••'
                      : balanceVisible
                      ? 'N${_formatBalance(balance)}'
                      : 'N••••••',
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -1.2,
                    height: 1.05,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggleVisible,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      balanceVisible
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: const Color(0xFFB8C4E8),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: _BalanceAction(
                  label: 'Deposit',
                  filled: true,
                  onTap: onDeposit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: _BalanceAction(
                  label: 'Withdraw',
                  filled: false,
                  onTap: onWithdraw,
                ),
              ),
              const SizedBox(width: 12),
              _PlusButton(onTap: onMore),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceAction extends StatelessWidget {
  const _BalanceAction({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? const Color(0xFF2F6BFF) : Colors.white,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.add_rounded, color: AppColors.primary, size: 26),
        ),
      ),
    );
  }
}

// ─── Services grid ───────────────────────────────────────────────────────────

class _ServiceItem {
  const _ServiceItem({
    required this.label,
    required this.bg,
    required this.iconColor,
    required this.icon,
    this.onTap,
  });

  final String label;
  final Color bg;
  final Color iconColor;
  final IconData icon;
  final VoidCallback? onTap;
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid({this.onOpenVirtualCard});

  final VoidCallback? onOpenVirtualCard;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ServiceItem(
        label: 'Airtime',
        bg: const Color(0xFFCFF5E1),
        iconColor: const Color(0xFF1FAE63),
        icon: Icons.call_rounded,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BuyAirtimeScreen()),
          );
        },
      ),
      _ServiceItem(
        label: 'Data',
        bg: const Color(0xFFFFF0C2),
        iconColor: const Color(0xFFD4A017),
        icon: Icons.cell_tower_rounded,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BuyDataScreen()),
          );
        },
      ),
      _ServiceItem(
        label: 'Electricity',
        bg: const Color(0xFFFFE0E0),
        iconColor: const Color.fromARGB(255, 206, 104, 102),
        icon: Icons.lightbulb_outline_rounded,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ElectricityScreen()),
          );
        },
      ),
      _ServiceItem(
        label: 'Cable Tv',
        bg: const Color(0xFFEDE0FF),
        iconColor: const Color(0xFF8B5CF6),
        icon: Icons.crop_square_rounded,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CableTvScreen()),
          );
        },
      ),
      _ServiceItem(
        label: 'Gift Cards',
        bg: const Color(0xFFD6F0FF),
        iconColor: const Color(0xFF2B9EDB),
        icon: Icons.card_giftcard_rounded,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const GiftCardScreen()),
          );
        },
      ),
      _ServiceItem(
        label: 'Crypto',
        bg: const Color(0xFFD4FBF6),
        iconColor: const Color(0xFF14B8A6),
        icon: Icons.currency_bitcoin_rounded,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const KycGuard(
                featureName: 'Crypto trading',
                featureReason:
                    'To keep your funds safe and comply with regulations, '
                    'we need to verify your identity before you can buy, '
                    'sell, swap or transfer crypto.',
                child: CryptoHubScreen(),
              ),
            ),
          );
        },
      ),
      _ServiceItem(
        label: 'Virtual Card',
        bg: const Color(0xFFE0E7FF),
        iconColor: const Color(0xFF4F6BED),
        icon: Icons.credit_card_rounded,
        onTap: onOpenVirtualCard,
      ),
    ];

    // 4 columns = modern proportions + larger tap targets.
    // Subtract outer screen padding (16*2), container padding (14*2),
    // and the 3 inter-item gaps (spacing 4) so 4 cells actually fit a row.
    const crossAxisCount = 4;
    const spacing = 8.0;
    final cellWidth =
        (MediaQuery.sizeOf(context).width -
            32 -
            28 -
            spacing * (crossAxisCount - 1)) /
        crossAxisCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        spacing: spacing,
        runSpacing: 18,
        children: items
            .map(
              (item) => SizedBox(
                width: cellWidth,
                child: _ServiceCell(item: item),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ServiceCell extends StatelessWidget {
  const _ServiceCell({required this.item});

  final _ServiceItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: item.bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: item.iconColor.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(item.icon, color: item.iconColor, size: 24),
          ),
          const SizedBox(height: 9),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent transactions ─────────────────────────────────────────────────────

class _RecentTransactionsHeader extends StatelessWidget {
  const _RecentTransactionsHeader({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: onSeeAll,
            child: const Text(
              'See All',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,

                decorationColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

({IconData icon, Color bg, Color fg}) _iconStyleFor(AppTxCategory category) {
  switch (category) {
    case AppTxCategory.deposit:
      return (
        icon: Icons.arrow_downward_rounded,
        bg: const Color(0xFFDCFCE7),
        fg: const Color(0xFF16A34A),
      );
    case AppTxCategory.withdrawal:
      return (
        icon: Icons.arrow_upward_rounded,
        bg: const Color(0xFFFFE4E4),
        fg: const Color(0xFFDC2626),
      );
    case AppTxCategory.airtime:
      return (
        icon: Icons.call_rounded,
        bg: const Color(0xFFCFF5E1),
        fg: const Color(0xFF1FAE63),
      );
    case AppTxCategory.data:
      return (
        icon: Icons.cell_tower_rounded,
        bg: const Color(0xFFFFF0C2),
        fg: const Color(0xFFD4A017),
      );
    case AppTxCategory.cryptoDeposit:
      return (
        icon: Icons.currency_exchange_rounded,
        bg: const Color(0xFFFFF1D6),
        fg: const Color(0xFFE59A0B),
      );
  }
}

class _NgnTransactionTile extends StatelessWidget {
  const _NgnTransactionTile({required this.tx});

  final AppTransaction tx;

  @override
  Widget build(BuildContext context) {
    final iconStyle = _iconStyleFor(tx.category);
    final amountColor = tx.isCredit
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);
    final statusColor = switch (tx.status) {
      AppTxStatus.completed => const Color(0xFF16A34A),
      AppTxStatus.pending => const Color(0xFFD97706),
      AppTxStatus.failed => const Color(0xFFDC2626),
    };
    final statusLabel = switch (tx.status) {
      AppTxStatus.completed => 'Completed',
      AppTxStatus.pending => 'Pending',
      AppTxStatus.failed => 'Failed',
    };

    return Material(
      color: const Color(0xFFF0F1F5),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => TransactionDetailsScreen(tx: tx),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconStyle.bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconStyle.icon, size: 20, color: iconStyle.fg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tx.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tx.amountLabel ??
                        '${tx.isCredit ? '+' : '-'}₦${_formatBalance(tx.amount)}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom navigation ───────────────────────────────────────────────────────

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(8, 10, 8, 10 + bottom),
      child: Row(
        children: [
          _NavItem(
            index: 0,
            current: currentIndex,
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
            onTap: onTap,
          ),
          _NavItem(
            index: 1,
            current: currentIndex,
            icon: Icons.grid_view_outlined,
            activeIcon: Icons.grid_view_rounded,
            label: 'Services',
            onTap: onTap,
          ),
          _NavItem(
            index: 2,
            current: currentIndex,
            icon: Icons.credit_card_outlined,
            activeIcon: Icons.credit_card_rounded,
            label: 'Virtual Card',
            onTap: onTap,
          ),
          _NavItem(
            index: 3,
            current: currentIndex,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Settings',
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.current,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int current;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    final color = active ? AppColors.primary : AppColors.textMuted;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern active pill indicator
              Container(
                decoration: active
                    ? BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      )
                    : null,
                padding: active
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
                    : EdgeInsets.zero,
                child: Icon(active ? activeIcon : icon, color: color, size: 24),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
