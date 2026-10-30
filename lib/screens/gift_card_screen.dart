import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/giftcard.dart';
import '../models/wallet.dart';
import '../services/api_exception.dart';
import '../services/giftcard_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import 'airtime_pin_screen.dart';
import 'gift_card_history_screen.dart';

class _Country {
  const _Country({required this.code, required this.name, required this.flag});
  final String code;
  final String name;
  final String flag;
}

const _countries = [
  _Country(code: 'US', name: 'United States', flag: '🇺🇸'),
  _Country(code: 'CA', name: 'Canada', flag: '🇨🇦'),
];

String _usdLabel(double v) => v % 1 == 0 ? '\$${v.toInt()}' : '\$${v.toStringAsFixed(2)}';

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

class GiftCardScreen extends StatefulWidget {
  const GiftCardScreen({super.key});

  @override
  State<GiftCardScreen> createState() => _GiftCardScreenState();
}

class _GiftCardScreenState extends State<GiftCardScreen> {
  final _customAmountController = TextEditingController();

  bool _loading = true;
  String? _loadError;
  double _ngnBalance = 0;
  double _rate = 0;

  _Country _country = _countries.first;
  List<GiftCardBrand> _brands = const [];
  GiftCardBrand? _selectedBrand;

  bool _productsLoading = false;
  String? _productError;
  List<GiftCardProduct> _products = const [];
  GiftCardProduct? _selectedProduct;
  bool _usingCustomAmount = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    super.dispose();
  }

  GiftCardProduct? get _openRangeProduct {
    for (final p in _products) {
      if (p.openRange) return p;
    }
    return null;
  }

  List<GiftCardProduct> get _fixedProducts =>
      _products.where((p) => !p.openRange).toList();

  /// Brand is out, or it loaded but none of its products can be bought.
  bool get _brandUnavailable =>
      _selectedBrand?.available == false ||
      (!_productsLoading && _products.isNotEmpty && !_products.any((p) => p.available));

  GiftCardBrand _defaultBrand(List<GiftCardBrand> brands) =>
      brands.firstWhere((b) => b.available, orElse: () => brands.first);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        GiftCardService.instance.getRate(),
        WalletService.instance.getWallet(),
        GiftCardService.instance.getBrands(countryCode: _country.code),
      ]);

      if (!mounted) return;
      setState(() {
        _rate = results[0] as double;
        _ngnBalance = (results[1] as WalletBalance).ngnBalance;
        _brands = results[2] as List<GiftCardBrand>;
        _loading = false;
      });

      if (_brands.isNotEmpty) {
        unawaited(_selectBrand(_defaultBrand(_brands)));
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
        _loadError = 'Could not load gift card brands. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<_Country>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CountrySheet(selected: _country),
    );
    if (selected == null || selected.code == _country.code || !mounted) return;

    setState(() {
      _country = selected;
      _brands = const [];
      _selectedBrand = null;
      _products = const [];
      _selectedProduct = null;
      _loading = true;
    });

    try {
      final brands = await GiftCardService.instance.getBrands(countryCode: selected.code);
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _loading = false;
      });
      if (brands.isNotEmpty) unawaited(_selectBrand(_defaultBrand(brands)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e is ApiException ? e.message : 'Failed to load brands for this country.';
        _loading = false;
      });
    }
  }

  Future<void> _selectBrand(GiftCardBrand brand) async {
    setState(() {
      _selectedBrand = brand;
      _products = const [];
      _selectedProduct = null;
      _usingCustomAmount = false;
      _customAmountController.clear();
      _productsLoading = true;
      _productError = null;
    });

    try {
      final products = await GiftCardService.instance.getProducts(
        brand: brand.brandName,
        countryCode: _country.code,
      );
      if (!mounted) return;

      final fixed = products.where((p) => !p.openRange && p.available).toList();
      final openAvailable = products.any((p) => p.openRange && p.available);
      setState(() {
        _products = products;
        _selectedProduct = fixed.isNotEmpty ? fixed.first : null;
        _usingCustomAmount = fixed.isEmpty && openAvailable;
        _productsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _productError = e is ApiException
            ? e.message
            : 'Could not load denominations for this brand.';
        _productsLoading = false;
      });
    }
  }

  Future<void> _pickBrand() async {
    final selected = await showModalBottomSheet<GiftCardBrand>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BrandPickerSheet(brands: _brands, selected: _selectedBrand),
    );
    if (selected != null && selected.brandId != _selectedBrand?.brandId) {
      _selectBrand(selected);
    }
  }

  void _onCustomAmountChanged(String value) {
    setState(() {
      _usingCustomAmount = value.trim().isNotEmpty;
      if (_usingCustomAmount) _selectedProduct = null;
    });
  }

  void _onSelectDenomination(GiftCardProduct product) {
    setState(() {
      _selectedProduct = product;
      _usingCustomAmount = false;
      _customAmountController.clear();
    });
  }

  double? get _usdAmount {
    if (_usingCustomAmount) {
      final raw = _customAmountController.text.replaceAll(',', '').trim();
      return raw.isEmpty ? null : double.tryParse(raw);
    }
    return _selectedProduct?.unitPriceUsd;
  }

  double get _ngnAmount => (_usdAmount ?? 0) * _rate;

  bool get _canContinue {
    final usd = _usdAmount;
    if (usd == null || usd <= 0 || _selectedBrand == null) return false;
    if (_brandUnavailable) return false;

    if (_usingCustomAmount) {
      final open = _openRangeProduct;
      if (open == null || !open.available) return false;
      if (open.minUsd == null || open.maxUsd == null) return false;
      if (usd < open.minUsd! || usd > open.maxUsd!) return false;
    } else if (_selectedProduct?.available != true) {
      return false;
    }
    return true;
  }

  Future<void> _onContinue() async {
    if (!_canContinue) return;

    final brand = _selectedBrand!;
    final product = _usingCustomAmount ? _openRangeProduct! : _selectedProduct!;
    final usd = _usdAmount!;
    final ngn = _ngnAmount;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConfirmSheet(
        brand: brand,
        usdAmount: usd,
        ngnAmount: ngn,
        balance: _ngnBalance,
      ),
    );

    if (confirmed != true || !mounted) return;

    GiftCardPurchase? purchase;
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AirtimePinScreen(
          amount: ngn,
          phone: brand.brandName,
          networkName: '${brand.brandName} Gift Card',
          onSubmit: (pin) async {
            purchase = await GiftCardService.instance.buy(
              productId: product.productId,
              unitPriceUsd: usd,
              brand: brand.brandName,
              countryCode: _country.code,
              transactionPin: pin,
            );
          },
        ),
      ),
    );

    if (paid == true && purchase != null && mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (ctx) => _GiftCardSuccessSheet(
          purchase: purchase!,
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
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              AuthPrimaryButton(label: 'Retry', onPressed: _load),
            ],
          ),
        ),
      );
    }

    final open = _openRangeProduct;
    final fixed = _fixedProducts;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Country', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _CountryRow(country: _country, onTap: _pickCountry),

          const SizedBox(height: 28),
          const Text('Brand', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          if (_brands.isEmpty)
            const Text('No brands available for this country.', style: TextStyle(color: AppColors.textMuted))
          else
            _SelectedBrandCard(
              brand: _selectedBrand,
              unavailable: _brandUnavailable,
              onTap: _pickBrand,
            ),

          if (_brandUnavailable) ...[
            const SizedBox(height: 12),
            const _InfoBanner(
              text: 'This gift card is currently unavailable. Please choose another brand.',
              icon: Icons.block_rounded,
            ),
          ],

          const SizedBox(height: 28),
          const Text('Select Amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          if (_productsLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else if (_productError != null)
            Text(_productError!, style: const TextStyle(color: AppColors.textSecondary))
          else if (fixed.isEmpty && open == null)
            const Text('No denominations available.', style: TextStyle(color: AppColors.textMuted))
          else ...[
            if (fixed.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: fixed.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final product = fixed[index];
                  final selected = !_usingCustomAmount && product.productId == _selectedProduct?.productId;
                  final ngn = product.unitPriceNgn ?? (product.unitPriceUsd ?? 0) * _rate;

                  return _DenominationCard(
                    usdLabel: _usdLabel(product.unitPriceUsd ?? 0),
                    ngnLabel: product.available ? _money(ngn) : 'Unavailable',
                    selected: selected,
                    enabled: product.available,
                    onTap: () => _onSelectDenomination(product),
                  );
                },
              ),
            if (open != null && open.available) ...[
              if (fixed.isNotEmpty) const SizedBox(height: 16),
              _OpenAmountField(
                controller: _customAmountController,
                min: open.minUsd ?? 0,
                max: open.maxUsd ?? 0,
                onChanged: _onCustomAmountChanged,
              ),
            ],
          ],

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Wallet Balance', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                Text(_money(_ngnBalance), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const _InfoBanner(
            text: 'Your redeem code is delivered instantly after successful payment.',
            icon: Icons.card_giftcard_rounded,
          ),
        ],
      ),
    );
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
              _ScreenHeader(
                title: 'Gift Cards',
                subtitle: 'Apple • Amazon • Google Play & more',
                onHistoryTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GiftCardHistoryScreen()),
                ),
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
                amountLabel: _canContinue ? _money(_ngnAmount) : null,
                onPressed: _onContinue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable Widgets ───────────────────────────────────────────────────────

class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.title, required this.subtitle, required this.onHistoryTap});

  final String title;
  final String subtitle;
  final VoidCallback onHistoryTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const AuthBackButton(),
          const Spacer(),
          Column(
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: onHistoryTap,
            icon: const Icon(Icons.history_rounded, size: 26),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({required this.country, required this.onTap});

  final _Country country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Text(country.flag, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(country.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Brand select ────────────────────────────────────────────────────────────

/// Compact "hero" row on the main screen — shows the current pick and opens
/// the full searchable picker rather than cramming every brand into a
/// horizontal scroller.
class _SelectedBrandCard extends StatelessWidget {
  const _SelectedBrandCard({required this.brand, required this.unavailable, required this.onTap});

  final GiftCardBrand? brand;
  final bool unavailable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = brand;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              if (selected != null)
                _BrandLogo(brand: selected, size: 52)
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: AppColors.primary, size: 26),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected?.brandName ?? 'Select a brand',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: selected != null ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      selected == null
                          ? 'Choose from the gift card catalogue'
                          : unavailable
                          ? 'Currently unavailable • Tap to change'
                          : 'Tap to change brand',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: unavailable ? const Color(0xFFDC2626) : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-height searchable grid of every brand for the current country.
class _BrandPickerSheet extends StatefulWidget {
  const _BrandPickerSheet({required this.brands, required this.selected});

  final List<GiftCardBrand> brands;
  final GiftCardBrand? selected;

  @override
  State<_BrandPickerSheet> createState() => _BrandPickerSheetState();
}

class _BrandPickerSheetState extends State<_BrandPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final filtered = widget.brands
        .where((b) => b.brandName.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Text('Select Brand', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search brand',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 22),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('No brands match your search.', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.82,
                    ),
                    itemBuilder: (context, index) {
                      final brand = filtered[index];
                      final isSelected = brand.brandId == widget.selected?.brandId;
                      return _BrandGridTile(
                        brand: brand,
                        selected: isSelected,
                        onTap: () => Navigator.of(context).pop(brand),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BrandGridTile extends StatelessWidget {
  const _BrandGridTile({required this.brand, required this.selected, required this.onTap});

  final GiftCardBrand brand;
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
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Opacity(
                    opacity: brand.available ? 1 : 0.4,
                    child: _BrandLogo(brand: brand, size: 48),
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
                brand.brandName,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: selected
                      ? AppColors.primary
                      : brand.available
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
              if (!brand.available)
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text(
                    'Unavailable',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.brand, required this.size});

  final GiftCardBrand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = brand.logoUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: SizedBox(
        width: size,
        height: size,
        child: url != null && url.isNotEmpty
            ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final initial = brand.brandName.isNotEmpty ? brand.brandName[0].toUpperCase() : '?';
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Text(initial, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primary)),
    );
  }
}

// Denomination Card
class _DenominationCard extends StatelessWidget {
  const _DenominationCard({
    required this.usdLabel,
    required this.ngnLabel,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String usdLabel;
  final String ngnLabel;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: _buildCard(),
    );
  }

  Widget _buildCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.07) : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border.withValues(alpha: 0.8),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(usdLabel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: selected ? AppColors.primary : null)),
              const SizedBox(height: 6),
              Text(ngnLabel, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenAmountField extends StatelessWidget {
  const _OpenAmountField({
    required this.controller,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final TextEditingController controller;
  final double min;
  final double max;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: 'Custom amount (\$${min.toStringAsFixed(0)} - \$${max.toStringAsFixed(0)})',
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 20, right: 8),
          child: Text('\$', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}

// Bottom Bar
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
    final label = amountLabel != null ? 'Pay $amountLabel' : 'Continue';

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottomPad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.9))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: AuthPrimaryButton(label: label, enabled: enabled, onPressed: onPressed),
    );
  }
}

// Info Banner
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDAE6FF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.45))),
        ],
      ),
    );
  }
}

// Country Sheet, Confirm Sheet, Success Sheet remain similar but cleaner
// (You can keep your existing _CountrySheet, _ConfirmSheet, _GiftCardSuccessSheet and just update styling if needed)

class _CountrySheet extends StatelessWidget {
  const _CountrySheet({required this.selected});
  final _Country selected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Country', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ..._countries.map((c) {
            final isSelected = c.code == selected.code;
            return InkWell(
              onTap: () => Navigator.pop(context, c),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Text(c.flag, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 16),
                    Expanded(child: Text(c.name, style: TextStyle(fontSize: 17, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500))),
                    if (isSelected) const Icon(Icons.check_rounded, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.brand,
    required this.usdAmount,
    required this.ngnAmount,
    required this.balance,
  });

  final GiftCardBrand brand;
  final double usdAmount;
  final double ngnAmount;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Confirm Purchase', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                child: const Icon(Icons.close_rounded, size: 24, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _BrandLogo(brand: brand, size: 56),
          const SizedBox(height: 14),
          Text(
            _money(ngnAmount),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            '${_usdLabel(usdAmount)} ${brand.brandName} gift card',
            style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _SummaryRow(label: 'Brand', value: brand.brandName),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Wallet Balance', value: _money(balance), bold: true),
          const SizedBox(height: 26),
          AuthPrimaryButton(
            label: 'Confirm Payment',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.bold = false});

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
        Text(
          value,
          style: TextStyle(fontSize: 14.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w700),
        ),
      ],
    );
  }
}

class _GiftCardSuccessSheet extends StatelessWidget {
  const _GiftCardSuccessSheet({required this.purchase, required this.onDone});

  final GiftCardPurchase purchase;
  final VoidCallback onDone;

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final hasCode = purchase.redeemCode.isNotEmpty;
    final pending = purchase.status == GiftCardStatus.pending;

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
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 10),
          Text(
            pending
                ? 'Your ${_usdLabel(purchase.unitPriceUsd)} ${purchase.brand} gift card is being '
                    'processed. We\'ll update your purchase history once the redeem code is ready.'
                : 'Your ${_usdLabel(purchase.unitPriceUsd)} ${purchase.brand} gift card is ready.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14.5, height: 1.45, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (hasCode) ...[
            _RedeemField(
              label: 'Card number',
              value: purchase.redeemCode,
              onCopy: () => _copy(context, 'Card number', purchase.redeemCode),
            ),
            if (purchase.redeemPin.isNotEmpty) ...[
              const SizedBox(height: 12),
              _RedeemField(
                label: 'PIN',
                value: purchase.redeemPin,
                onCopy: () => _copy(context, 'PIN', purchase.redeemPin),
              ),
            ],
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'Your card is being processed and will appear in your purchase history shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 26),
          AuthPrimaryButton(label: 'Done', onPressed: onDone),
        ],
      ),
    );
  }
}

class _RedeemField extends StatelessWidget {
  const _RedeemField({required this.label, required this.value, required this.onCopy});

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onCopy,
            child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}