/// Reading wallet / exchange deposit QR codes.
///
/// Apps encode a deposit address either as the bare address or as a payment
/// URI — `bitcoin:bc1q…?amount=0.01`, `tron:T…`, `litecoin:…`, or EIP-681
/// for EVM chains (`ethereum:0x…@56`, and for tokens
/// `ethereum:<token contract>@1/transfer?address=<recipient>&uint256=…`,
/// where the recipient is in the query, not the path).
library;

/// Address formats we can recognise well enough to warn about a network
/// mismatch. Anything else is [unknown] and never triggers a warning.
enum AddressFamily { evm, tron, bitcoin, solana, unknown }

extension AddressFamilyLabel on AddressFamily {
  String get label => switch (this) {
    AddressFamily.evm => 'EVM (Ethereum / BNB Smart Chain style)',
    AddressFamily.tron => 'TRON',
    AddressFamily.bitcoin => 'Bitcoin',
    AddressFamily.solana => 'Solana',
    AddressFamily.unknown => 'unknown',
  };
}

/// What a scanned QR code holds.
class CryptoQrPayload {
  const CryptoQrPayload({
    required this.address,
    this.coinSymbol,
    this.amount,
    this.memo,
  });

  final String address;

  /// Coin the URI scheme names (`bitcoin:` → `btc`), when it names one.
  /// Null for bare addresses and EIP-681 token transfers.
  final String? coinSymbol;

  /// Human-unit amount from `?amount=`, if the QR requested one.
  final String? amount;

  /// Memo / destination tag some exchanges require alongside the address.
  final String? memo;
}

const _schemeCoins = <String, String>{
  'bitcoin': 'btc',
  'litecoin': 'ltc',
  'dogecoin': 'doge',
  'bitcoincash': 'bch',
  'ethereum': 'eth',
  'tron': 'trx',
  'solana': 'sol',
  'ripple': 'xrp',
  'xrp': 'xrp',
  'xrpl': 'xrp',
  'stellar': 'xlm',
  'cardano': 'ada',
  'polygon': 'pol',
  'bnb': 'bnb',
  'dash': 'dash',
};

final _scheme = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]*):(.*)$', dotAll: true);
final _addressChars = RegExp(r'^[A-Za-z0-9_\-]{20,120}$');
final _amount = RegExp(r'^\d+(\.\d+)?$');

/// Pulls a deposit address out of a scanned QR [raw] value, or null when it
/// doesn't hold one (a website link, plain text, …).
CryptoQrPayload? parseCryptoQr(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final m = _scheme.firstMatch(text);
  // "0x…" never matches (digit first), so bare EVM addresses skip this.
  if (m == null) {
    return _addressChars.hasMatch(text) ? CryptoQrPayload(address: text) : null;
  }

  final scheme = m.group(1)!.toLowerCase();
  if (scheme == 'http' || scheme == 'https') return null;

  var rest = m.group(2)!;
  if (rest.startsWith('//')) rest = rest.substring(2);
  final q = rest.indexOf('?');
  var path = q < 0 ? rest : rest.substring(0, q);
  final query = q < 0
      ? const <String, String>{}
      : _safeQuery(rest.substring(q + 1));

  // `pay-0x…` is EIP-681's explicit payment-request prefix.
  if (path.startsWith('pay-')) path = path.substring(4);

  String address;
  var isTokenTransfer = false;
  final slash = path.indexOf('/');
  final function = slash < 0 ? null : path.substring(slash + 1).toLowerCase();
  if (function == 'transfer' && query['address'] != null) {
    // EIP-681 token transfer: the path is the token contract.
    address = query['address']!;
    isTokenTransfer = true;
  } else {
    address = slash < 0 ? path : path.substring(0, slash);
  }
  // Strip EIP-681 "@chainId".
  final at = address.indexOf('@');
  if (at >= 0) address = address.substring(0, at);
  address = Uri.decodeComponent(address).trim();

  if (!_addressChars.hasMatch(address)) return null;

  final amount = query['amount'];
  return CryptoQrPayload(
    address: address,
    coinSymbol: isTokenTransfer ? null : _schemeCoins[scheme],
    amount: amount != null && _amount.hasMatch(amount) ? amount : null,
    memo: _firstNonEmpty([
      query['memo'],
      query['dt'],
      query['tag'],
      query['destinationtag'],
      query['destination_tag'],
    ]),
  );
}

Map<String, String> _safeQuery(String query) {
  try {
    return Uri.splitQueryString(
      query,
    ).map((k, v) => MapEntry(k.toLowerCase(), v));
  } on FormatException {
    return const {};
  }
}

String? _firstNonEmpty(List<String?> values) {
  for (final v in values) {
    if (v != null && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

final _evm = RegExp(r'^0x[0-9a-fA-F]{40}$');
final _tron = RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{33}$');
final _btc = RegExp(
  r'^(bc1[02-9ac-hj-np-z]{11,71}|[13][1-9A-HJ-NP-Za-km-z]{25,34})$',
);
final _solana = RegExp(r'^[1-9A-HJ-NP-Za-km-z]{32,44}$');

/// Whether [address] is shaped like an address on a [family] network.
/// Always true for [AddressFamily.unknown] — no basis to object.
bool addressFitsFamily(String address, AddressFamily family) {
  final a = address.trim();
  return switch (family) {
    AddressFamily.evm => _evm.hasMatch(a),
    AddressFamily.tron => _tron.hasMatch(a),
    AddressFamily.bitcoin => _isBitcoin(a),
    AddressFamily.solana => _solana.hasMatch(a),
    AddressFamily.unknown => true,
  };
}

/// The most likely format of [address], for wording a warning. Some
/// strings fit more than one (a short base58 string can be Bitcoin or
/// Solana), so use [addressFitsFamily] for the actual check.
AddressFamily addressFamily(String address) {
  final a = address.trim();
  if (_evm.hasMatch(a)) return AddressFamily.evm;
  if (_tron.hasMatch(a)) return AddressFamily.tron;
  if (_isBitcoin(a)) return AddressFamily.bitcoin;
  if (_solana.hasMatch(a)) return AddressFamily.solana;
  return AddressFamily.unknown;
}

/// Best guess at which address format a network takes, from Quidax's code /
/// label (e.g. `trc20` / "Tron (TRC20)"). Unknown when it can't tell.
AddressFamily networkFamily(String code, String label) {
  final s = '$code $label'.toLowerCase();
  bool has(String p) => RegExp(p).hasMatch(s);
  if (has(r'trc|tron')) return AddressFamily.tron;
  if (has(
    r'erc|bep|bsc|polygon|matic|arbitrum|optimism|avax|c-chain|\bbase\b|ethereum|\beth\b',
  )) {
    return AddressFamily.evm;
  }
  if (has(r'\bsol|solana|spl')) return AddressFamily.solana;
  if (has(r'\bbtc\b|bitcoin(?! ?cash)')) return AddressFamily.bitcoin;
  return AddressFamily.unknown;
}

/// Bech32 (`bc1…`) is case-insensitive and often upper-cased in QR codes.
bool _isBitcoin(String a) =>
    _btc.hasMatch(a.toLowerCase().startsWith('bc1') ? a.toLowerCase() : a);
