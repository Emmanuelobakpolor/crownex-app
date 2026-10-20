import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/crypto.dart';
import '../services/api_exception.dart';
import '../services/crypto_service.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/auto_convert_tile.dart';

/// Deposit Crypto — select token/network, fetch and show the real Quidax
/// deposit address (QR + copy).
class DepositCryptoScreen extends StatefulWidget {
  const DepositCryptoScreen({super.key});

  @override
  State<DepositCryptoScreen> createState() => _DepositCryptoScreenState();
}

class _DepositCryptoScreenState extends State<DepositCryptoScreen> {
  final _crypto = CryptoService.instance;

  bool _cryptoMode = true;
  List<CryptoCoin> _coins = const [];
  bool _loadingCoins = true;
  String? _coinsError;

  CryptoCoin? _token;
  String? _network;

  bool _loadingAddress = false;
  String? _addressError;
  CryptoDepositAddress? _address;

  bool get _needsNetwork =>
      _token != null && kCryptoCoinNetworks.containsKey(_token!.symbol);

  bool get _canContinue =>
      _token != null && (!_needsNetwork || _network != null);

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    setState(() {
      _loadingCoins = true;
      _coinsError = null;
    });
    try {
      final coins = await _crypto.getPrices();
      if (!mounted) return;
      setState(() {
        _coins = coins;
        _loadingCoins = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _coinsError = e.message;
        _loadingCoins = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _coinsError = 'Could not load coins. Please try again.';
        _loadingCoins = false;
      });
    }
  }

  Future<void> _pickToken() async {
    final selected = await showModalBottomSheet<CryptoCoin>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _TokenPickerSheet(tokens: _coins, selected: _token),
    );
    if (selected != null) {
      setState(() {
        _token = selected;
        _network = kCryptoCoinNetworks[selected.symbol]?.first;
        _address = null;
        _addressError = null;
      });
    }
  }

  Future<void> _pickNetwork() async {
    if (_token == null) return;
    final options = kCryptoCoinNetworks[_token!.symbol];
    if (options == null) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _NetworkPickerSheet(networks: options, selected: _network),
    );
    if (selected != null) {
      setState(() {
        _network = selected;
        _address = null;
        _addressError = null;
      });
    }
  }

  Future<void> _onContinue() async {
    if (!_canContinue || _token == null) return;

    setState(() {
      _loadingAddress = true;
      _addressError = null;
    });

    try {
      final address = await _crypto.getDepositAddress(_token!.symbol, network: _network);
      if (!mounted) return;
      setState(() {
        _address = address;
        _loadingAddress = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _addressError = e.message;
        _loadingAddress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addressError = 'Could not load a deposit address. Please try again.';
        _loadingAddress = false;
      });
    }
  }

  Future<void> _copyAddress() async {
    final address = _address?.address;
    if (address == null) return;
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wallet address copied'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final showDetails = _address != null;

    return PopScope(
      canPop: !showDetails,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _address = null);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                _Header(
                  title: 'Deposit Crypto',
                  onBack: () {
                    if (showDetails) {
                      setState(() => _address = null);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: showDetails
                        ? _DepositDetailsView(
                            token: _token!,
                            network: _network,
                            address: _address!,
                            onPickToken: () => setState(() => _address = null),
                            onCopy: _copyAddress,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CryptoFiatTabs(
                                cryptoMode: _cryptoMode,
                                onChanged: (v) => setState(() => _cryptoMode = v),
                              ),
                              const SizedBox(height: 22),
                              if (!_cryptoMode)
                                const _FiatPlaceholder()
                              else if (_loadingCoins)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              else if (_coinsError != null)
                                _ErrorState(message: _coinsError!, onRetry: _loadCoins)
                              else ...[
                                _SelectField(
                                  value: _token?.symbol.toUpperCase(),
                                  placeholder: 'Select Token',
                                  onTap: _pickToken,
                                  leading: _token != null ? _TokenDot(coin: _token!, size: 24) : null,
                                ),
                                if (_needsNetwork) ...[
                                  const SizedBox(height: 14),
                                  _SelectField(
                                    value: _network,
                                    placeholder: 'Select Network',
                                    onTap: _pickNetwork,
                                  ),
                                ],
                                if (_addressError != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _addressError!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomPad),
                  child: showDetails
                      ? AuthPrimaryButton(
                          label: 'Noted',
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      : Column(
                          children: [
                            AuthPrimaryButton(
                              label: 'Continue',
                              enabled: _canContinue,
                              loading: _loadingAddress,
                              onPressed: _onContinue,
                            ),
                            const SizedBox(height: 12),
                            _SecondaryButton(
                              label: 'Cancel Transaction',
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ],
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

// ─── Deposit details (real QR + address) ─────────────────────────────────────

class _DepositDetailsView extends StatelessWidget {
  const _DepositDetailsView({
    required this.token,
    required this.network,
    required this.address,
    required this.onPickToken,
    required this.onCopy,
  });

  final CryptoCoin token;
  final String? network;
  final CryptoDepositAddress address;
  final VoidCallback onPickToken;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CryptoFiatTabs(cryptoMode: true, onChanged: null),
        const SizedBox(height: 18),
        _SelectField(
          value: token.symbol.toUpperCase(),
          placeholder: 'Select Token',
          onTap: onPickToken,
          leading: _TokenDot(coin: token, size: 24),
        ),
        if (network != null) ...[
          const SizedBox(height: 12),
          _SelectField(value: network, placeholder: 'Select Network', onTap: onPickToken),
        ],
        const SizedBox(height: 28),
        const Center(
          child: Text(
            'Scan to send token or copy address to pay',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: QrImageView(
              data: address.address,
              size: 180,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Wallet Address',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  address.address,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Copy',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Please Note:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _NoteBullet(
                'This address only accepts ${token.symbol.toUpperCase()}'
                '${network != null ? ' on $network' : ''}. Sending anything else may result in permanent loss.',
              ),
              const SizedBox(height: 8),
              const _NoteBullet(
                'Deposits are credited automatically once confirmed on-chain — this can take a few minutes.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: AutoConvertTile(
            subtitleBuilder: (enabled) => switch (enabled) {
              true => 'Deposits to this address will be converted to NGN automatically.',
              false => "You'll keep this as crypto.",
              null => 'Sell incoming crypto at the live rate',
            },
          ),
        ),
      ],
    );
  }
}

class _NoteBullet extends StatelessWidget {
  const _NoteBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '•  ',
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.primary),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Token picker ────────────────────────────────────────────────────────────

class _TokenPickerSheet extends StatefulWidget {
  const _TokenPickerSheet({required this.tokens, required this.selected});

  final List<CryptoCoin> tokens;
  final CryptoCoin? selected;

  @override
  State<_TokenPickerSheet> createState() => _TokenPickerSheetState();
}

class _TokenPickerSheetState extends State<_TokenPickerSheet> {
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
    final filtered = widget.tokens.where((t) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return t.symbol.toLowerCase().contains(q) || t.name.toLowerCase().contains(q);
    }).toList();

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 12 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Select Token',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close_rounded, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Kindly select the token you'll love to deposit",
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search token name',
              hintStyle: const TextStyle(fontSize: 15, color: AppColors.textMuted),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textMuted,
                size: 22,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F6F8),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No tokens found',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFEEF0F4)),
                    itemBuilder: (context, index) {
                      final token = filtered[index];
                      final selected = widget.selected?.symbol == token.symbol;
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(token),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              _TokenDot(coin: token, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      token.symbol.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      token.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        selected ? AppColors.primary : AppColors.border,
                                    width: selected ? 6 : 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Network picker ──────────────────────────────────────────────────────────

class _NetworkPickerSheet extends StatelessWidget {
  const _NetworkPickerSheet({required this.networks, required this.selected});

  final List<String> networks;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(8, 16, 8, 12 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Network',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          ...networks.map((network) {
            final isSelected = selected == network;
            return ListTile(
              title: Text(
                network,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.of(context).pop(network),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Shared widgets ──────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: AuthBackButton(onPressed: onBack)),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CryptoFiatTabs extends StatelessWidget {
  const _CryptoFiatTabs({required this.cryptoMode, required this.onChanged});

  final bool cryptoMode;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabChip(
              label: 'Crypto',
              selected: cryptoMode,
              onTap: onChanged == null ? null : () => onChanged!(true),
            ),
          ),
          Expanded(
            child: _TabChip(
              label: 'Fiat',
              selected: !cryptoMode,
              onTap: onChanged == null ? null : () => onChanged!(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.leading,
  });

  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final has = value != null && value!.isNotEmpty;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              Expanded(
                child: Text(
                  has ? value! : placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                    color: has ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real coin icon from the backend's CoinCap-CDN logo_url, falling back to
/// a color+letter circle if the image fails to load.
class _TokenDot extends StatelessWidget {
  const _TokenDot({required this.coin, this.size = 28});

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

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: const Color(0xFFD6DEFF),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B6C9B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FiatPlaceholder extends StatelessWidget {
  const _FiatPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.account_balance_rounded, size: 40, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Fiat deposit coming soon',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Use the Crypto tab to deposit tokens for now.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
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
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(16),
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
