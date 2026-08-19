import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/crypto.dart';
import '../services/api_exception.dart';
import '../services/crypto_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'crypto_screen.dart';
import 'deposit_crypto_screen.dart';
import 'swap_crypto_screen.dart';
import 'transfer_crypto_screen.dart';

String _fmt(double v, {int decimals = 2}) {
  final fixed = v.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  if (decimals == 0) return buf.toString();
  return '${buf.toString()}.${parts[1]}';
}

String _fmtNgn(double v) => '₦${_fmt(v)}';

/// Crypto Hub — the front door to every crypto feature: portfolio value,
/// quick actions, holdings, and the live market. Fires a best-effort
/// Quidax sub-account warm-up the instant it opens.
class CryptoHubScreen extends StatefulWidget {
  const CryptoHubScreen({super.key});

  @override
  State<CryptoHubScreen> createState() => _CryptoHubScreenState();
}

class _CryptoHubScreenState extends State<CryptoHubScreen> {
  final _crypto = CryptoService.instance;

  bool _loading = true;
  String? _error;
  List<CryptoCoin> _coins = const [];
  List<CryptoWalletBalance> _wallets = const [];

  @override
  void initState() {
    super.initState();
    // Fire-and-forget — never awaited, never blocks this screen.
    _crypto.ensureAccount();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_crypto.getPrices(), _crypto.getWallets()]);
      if (!mounted) return;
      setState(() {
        _coins = results[0] as List<CryptoCoin>;
        _wallets = results[1] as List<CryptoWalletBalance>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your portfolio. Please try again.';
        _loading = false;
      });
    }
  }

  Map<String, CryptoCoin> get _coinBySymbol => {for (final c in _coins) c.symbol: c};

  double get _portfolioValueNgn {
    final priceMap = _coinBySymbol;
    var total = 0.0;
    for (final w in _wallets) {
      final rate = priceMap[w.coin]?.rateNgn;
      if (rate != null) total += w.total * rate;
    }
    return total;
  }

  List<CryptoWalletBalance> get _holdings =>
      _wallets.where((w) => w.total > 0).toList()
        ..sort((a, b) {
          final priceMap = _coinBySymbol;
          final aVal = a.total * (priceMap[a.coin]?.rateNgn ?? 0);
          final bVal = b.total * (priceMap[b.coin]?.rateNgn ?? 0);
          return bVal.compareTo(aVal);
        });

  void _openBuy() => _push(const CryptoScreen());
  void _openSell() => _push(const CryptoScreen(initialBuyMode: false));
  void _openSwap() => _push(const SwapCryptoScreen());
  void _openSend() => _push(const TransferCryptoScreen());
  void _openReceive() => _push(const DepositCryptoScreen());

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _HubHeader(onBack: () => Navigator.of(context).pop()),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _PortfolioCard(
                      valueNgn: _portfolioValueNgn,
                      loading: _loading,
                      holdingsCount: _holdings.length,
                      onBuy: _openBuy,
                      onReceive: _openReceive,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: _QuickActionsRow(
                      onBuy: _openBuy,
                      onSell: _openSell,
                      onSwap: _openSwap,
                      onSend: _openSend,
                      onReceive: _openReceive,
                    ),
                  ),
                ),
                if (_loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
                      child: _ErrorState(message: _error!, onRetry: _load),
                    ),
                  )
                else ...[
                  if (_holdings.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
                        child: _SectionLabel('Your assets'),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList.separated(
                        itemCount: _holdings.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final wallet = _holdings[index];
                          final coin = _coinBySymbol[wallet.coin];
                          return _HoldingTile(
                            wallet: wallet,
                            coin: coin,
                            onTap: coin == null ? null : _openSell,
                          );
                        },
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
                      child: _SectionLabel('Market'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.separated(
                      itemCount: _coins.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _MarketTile(coin: _coins[index], onTap: _openBuy),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _HubHeader extends StatelessWidget {
  const _HubHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AuthBackButton(onPressed: onBack),
        const SizedBox(width: 12),
        const Text(
          'Crypto',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

// ─── Portfolio hero card ─────────────────────────────────────────────────────

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({
    required this.valueNgn,
    required this.loading,
    required this.holdingsCount,
    required this.onBuy,
    required this.onReceive,
  });

  final double valueNgn;
  final bool loading;
  final int holdingsCount;
  final VoidCallback onBuy;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
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
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pie_chart_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'Portfolio value',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            loading ? '₦••••••' : _fmtNgn(valueNgn),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1.1,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loading
                ? 'Loading your holdings…'
                : holdingsCount == 0
                    ? 'No holdings yet — fund your wallet to get started'
                    : '$holdingsCount asset${holdingsCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _HeroAction(label: 'Buy', filled: true, onTap: onBuy)),
              const SizedBox(width: 10),
              Expanded(child: _HeroAction(label: 'Receive', filled: false, onTap: onReceive)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
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
      color: filled ? Colors.white : Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(
          height: 46,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: filled ? const Color(0xFF041B6B) : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quick actions ───────────────────────────────────────────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onBuy,
    required this.onSell,
    required this.onSwap,
    required this.onSend,
    required this.onReceive,
  });

  final VoidCallback onBuy;
  final VoidCallback onSell;
  final VoidCallback onSwap;
  final VoidCallback onSend;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.add_rounded, 'Buy', onBuy, const Color(0xFF16A34A)),
      (Icons.remove_rounded, 'Sell', onSell, const Color(0xFFDC2626)),
      (Icons.swap_horiz_rounded, 'Swap', onSwap, AppColors.primary),
      (Icons.north_east_rounded, 'Send', onSend, const Color(0xFFEA580C)),
      (Icons.south_west_rounded, 'Receive', onReceive, const Color(0xFF0891B2)),
    ];

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _QuickActionButton(
              icon: actions[i].$1,
              label: actions[i].$2,
              onTap: actions[i].$3,
              color: actions[i].$4,
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

// ─── Holding tile ────────────────────────────────────────────────────────────

class _HoldingTile extends StatelessWidget {
  const _HoldingTile({required this.wallet, required this.coin, this.onTap});

  final CryptoWalletBalance wallet;
  final CryptoCoin? coin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rate = coin?.rateNgn;
    final valueNgn = rate != null ? wallet.total * rate : null;
    final decimals = wallet.total < 1 ? 6 : 2;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          child: Row(
            children: [
              coin != null
                  ? _CoinLogo(coin: coin!, size: 40)
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        wallet.coin.isNotEmpty ? wallet.coin[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${_fmt(wallet.total, decimals: decimals)} ${wallet.coin.toUpperCase()}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                valueNgn != null ? _fmtNgn(valueNgn) : '—',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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

// ─── Market tile ─────────────────────────────────────────────────────────────

class _MarketTile extends StatelessWidget {
  const _MarketTile({required this.coin, required this.onTap});

  final CryptoCoin coin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
          ),
          child: Row(
            children: [
              _CoinLogo(coin: coin, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coin.symbol.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      coin.name,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                coin.rateNgn != null ? _fmtNgn(coin.rateNgn!) : 'Unavailable',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: coin.rateNgn != null ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real coin icon from the backend's CoinCap-CDN logo_url, falling back to
/// a color+letter circle if the image fails to load.
class _CoinLogo extends StatelessWidget {
  const _CoinLogo({required this.coin, this.size = 28});

  final CryptoCoin coin;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.network(
        coin.logoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: colorFromHex(coin.color), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            coin.letter,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
