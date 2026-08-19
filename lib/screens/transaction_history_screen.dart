import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wallet.dart';
import '../services/wallet_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';

/// GET /wallet/transactions/ — tabbed, grouped-by-day history with
/// pull-to-refresh. Status (pending/completed/failed) always reflects the
/// server's record, which is the source of truth once a webhook lands.
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _wallet = WalletService.instance;

  bool _loading = true;
  String? _error;
  List<WalletTransaction> _transactions = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final transactions = await _wallet.getTransactions();
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load transactions.';
        _loading = false;
      });
    }
  }

  List<WalletTransaction> get _filtered {
    switch (_tabController.index) {
      case 1:
        return _transactions.where((t) => t.txType == TxType.deposit).toList();
      case 2:
        return _transactions
            .where((t) => t.txType == TxType.withdrawal)
            .toList();
      default:
        return _transactions;
    }
  }

  Map<String, List<WalletTransaction>> get _grouped {
    final grouped = <String, List<WalletTransaction>>{};
    for (final tx in _filtered) {
      final label = _dateLabel(tx.createdAt);
      grouped.putIfAbsent(label, () => []).add(tx);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
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
                        child: AuthBackButton(
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const Text(
                        'Transaction History',
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
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Deposits'),
                  Tab(text: 'Withdrawals'),
                ],
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

  Widget _buildBody(Map<String, List<WalletTransaction>> grouped) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Center(
            child: Text(_error!, style: const TextStyle(color: AppColors.textMuted)),
          ),
        ],
      );
    }

    if (grouped.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          _EmptyState(),
        ],
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            for (final tx in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TransactionRow(tx: tx),
              ),
          ],
        );
      },
    );
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
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.tx});

  final WalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    final isDeposit = tx.txType == TxType.deposit;
    final amountColor = isDeposit ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final sign = isDeposit ? '+' : '-';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isDeposit
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFFE4E4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDeposit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 20,
              color: amountColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDeposit ? 'Deposit' : 'Withdrawal',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isDeposit
                      ? tx.reference
                      : (tx.bankName.isNotEmpty
                          ? '${tx.bankName} • ${tx.accountNumber}'
                          : tx.reference),
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
                '$sign₦${_formatAmount(tx.amount)}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 5),
              _StatusPill(status: tx.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final TxStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TxStatus.completed => ('Completed', const Color(0xFF16A34A)),
      TxStatus.pending => ('Pending', const Color(0xFFD97706)),
      TxStatus.failed => ('Failed', const Color(0xFFDC2626)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
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
          decoration: BoxDecoration(
            color: AppColors.fieldFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            size: 32,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'No transactions yet',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your deposits and withdrawals will show up here',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

String _formatAmount(double v) {
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
