import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/kyc_guard.dart';
import 'buy_airtime_screen.dart';
import 'buy_data_screen.dart';
import 'cable_tv_screen.dart';
import 'crypto_hub_screen.dart';
import 'deposit_ngn_screen.dart';
import 'electricity_screen.dart';
import 'gift_card_screen.dart';
import 'withdraw_ngn_screen.dart';

class _ServiceEntry {
  const _ServiceEntry({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
}

class _PromoSlide {
  const _PromoSlide({
    required this.imageUrl,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String imageUrl;
  final String tag;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

/// Services — the full catalogue of everything CrownEx offers, reachable
/// from the bottom nav. Fronted by an auto-sliding promo carousel showcasing
/// the app's flagship features.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, this.onOpenVirtualCard});

  final VoidCallback? onOpenVirtualCard;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  void _pushCrypto(BuildContext context) {
    _push(
      context,
      const KycGuard(
        featureName: 'Crypto trading',
        featureReason:
            'To keep your funds safe and comply with regulations, we '
            'need to verify your identity before you can buy, sell, swap '
            'or transfer crypto.',
        child: CryptoHubScreen(),
      ),
    );
  }

  void _pushDepositNgn(BuildContext context) {
    _push(
      context,
      const KycGuard(
        featureName: 'Fiat deposits',
        featureReason:
            'To keep your funds safe and comply with regulations, we '
            'need to verify your identity before you can deposit money.',
        child: DepositNgnScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final money = [
      _ServiceEntry(
        icon: Icons.add_card_rounded,
        label: 'Add Money',
        subtitle: 'Fund your NGN wallet',
        color: const Color(0xFF16A34A),
        onTap: () => _pushDepositNgn(context),
      ),
      _ServiceEntry(
        icon: Icons.account_balance_rounded,
        label: 'Withdraw',
        subtitle: 'Send money to your bank',
        color: const Color(0xFFEA580C),
        onTap: () => _push(context, const WithdrawNgnScreen()),
      ),
    ];

    final bills = [
      _ServiceEntry(
        icon: Icons.call_rounded,
        label: 'Airtime',
        subtitle: 'Top up any network',
        color: const Color(0xFF1FAE63),
        onTap: () => _push(context, const BuyAirtimeScreen()),
      ),
      _ServiceEntry(
        icon: Icons.cell_tower_rounded,
        label: 'Data',
        subtitle: 'Internet bundles, all networks',
        color: const Color(0xFFD4A017),
        onTap: () => _push(context, const BuyDataScreen()),
      ),
      _ServiceEntry(
        icon: Icons.crop_square_rounded,
        label: 'Cable TV',
        subtitle: 'DStv, GOtv, StarTimes',
        color: const Color(0xFF8B5CF6),
        onTap: () => _push(context, const CableTvScreen()),
      ),
      _ServiceEntry(
        icon: Icons.lightbulb_outline_rounded,
        label: 'Electricity',
        subtitle: 'Prepaid & postpaid tokens',
        color: const Color(0xFFCE6866),
        onTap: () => _push(context, const ElectricityScreen()),
      ),
    ];

    final more = [
      _ServiceEntry(
        icon: Icons.card_giftcard_rounded,
        label: 'Gift Cards',
        subtitle: 'Buy & sell Apple, Amazon, Steam and more',
        color: const Color(0xFF2B9EDB),
        onTap: () => _push(context, const GiftCardScreen()),
      ),
      _ServiceEntry(
        icon: Icons.credit_card_rounded,
        label: 'Virtual Card',
        subtitle: 'Spend online, anywhere',
        color: const Color(0xFF4F6BED),
        onTap: widget.onOpenVirtualCard,
      ),
    ];

    final slides = [
      _PromoSlide(
        imageUrl: 'https://images.unsplash.com/photo-1621761191319-c6fb62004040?w=800&q=80',
        tag: 'CRYPTO',
        title: 'Buy, sell & swap crypto',
        subtitle: 'Live rates on 26 coins, instantly',
        onTap: () => _pushCrypto(context),
      ),
      _PromoSlide(
        imageUrl: 'https://images.unsplash.com/photo-1580519542036-c47de6196ba5?w=800&q=80',
        tag: 'AIRTIME & DATA',
        title: 'Never run out of data',
        subtitle: 'Instant top-ups on every network',
        onTap: () => _push(context, const BuyAirtimeScreen()),
      ),
      _PromoSlide(
        imageUrl: 'https://images.unsplash.com/photo-1593359677879-a4bb92f829d1?w=800&q=80',
        tag: 'BILLS',
        title: 'Bills, sorted in seconds',
        subtitle: 'Electricity & cable TV, zero queues',
        onTap: () => _push(context, const ElectricityScreen()),
      ),
      _PromoSlide(
        imageUrl: 'https://images.unsplash.com/photo-1607344645866-009c320b63e0?w=800&q=80',
        tag: 'GIFT CARDS',
        title: 'Turn gift cards into cash',
        subtitle: 'Apple, Amazon, Steam and more',
        onTap: () => _push(context, const GiftCardScreen()),
      ),
      _PromoSlide(
        imageUrl: 'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=800&q=80',
        tag: 'VIRTUAL CARD',
        title: 'Spend online, anywhere',
        subtitle: 'A dollar card that just works',
        onTap: () => widget.onOpenVirtualCard?.call(),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  'Services',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Text(
                  'Everything you need, in one place',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _PromoCarousel(slides: slides),
              ),
            ),
            SliverToBoxAdapter(
              child: _ServiceSection(title: 'Money', entries: money),
            ),
            SliverToBoxAdapter(
              child: _ServiceSection(title: 'Bills & Utilities', entries: bills),
            ),
            SliverToBoxAdapter(
              child: _ServiceSection(title: 'More', entries: more),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ─── Promo carousel ───────────────────────────────────────────────────────────

class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel({required this.slides});

  final List<_PromoSlide> slides;

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  late final PageController _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.slides.isEmpty) return;
      final next = (_page + 1) % widget.slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  var scale = 1.0;
                  if (_controller.position.haveDimensions) {
                    final delta = (_controller.page ?? _page.toDouble()) - index;
                    scale = (1 - (delta.abs() * 0.08)).clamp(0.92, 1.0);
                  }
                  return Transform.scale(scale: scale, child: child);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _PromoCard(slide: widget.slides[index]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _page == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _page == i
                      ? const Color(0xFF041B6B)
                      : const Color(0xFF041B6B).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.slide});

  final _PromoSlide slide;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: slide.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF041B6B).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                slide.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(color: const Color(0xFF041B6B));
                },
                errorBuilder: (context, error, stack) =>
                    Container(color: const Color(0xFF041B6B)),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF020B2E).withValues(alpha: 0.92),
                      const Color(0xFF041B6B).withValues(alpha: 0.55),
                      const Color(0xFF041B6B).withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              slide.tag,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            slide.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            slide.subtitle,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section ─────────────────────────────────────────────────────────────────

class _ServiceSection extends StatelessWidget {
  const _ServiceSection({required this.title, required this.entries});

  final String title;
  final List<_ServiceEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  _ServiceRow(entry: entries[i]),
                  if (i < entries.length - 1)
                    const Divider(height: 1, indent: 68, color: Color(0xFFF0F1F5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.entry});

  final _ServiceEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: entry.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: entry.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(entry.icon, color: entry.color, size: 21),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
