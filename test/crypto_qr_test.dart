import 'package:crownex/services/crypto_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const evm = '0x52908400098527886E0F7030069857D2E4169EE7';
  const tron = 'TLa2f6VPqDgRE67v1736s7bJ8Ray5wYjU7';
  const btc = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';

  group('parseCryptoQr', () {
    test('bare addresses', () {
      expect(parseCryptoQr(evm)!.address, evm);
      expect(parseCryptoQr('  $tron\n')!.address, tron);
      expect(parseCryptoQr(btc)!.coinSymbol, isNull);
    });

    test('BIP-21 with amount and label', () {
      final p = parseCryptoQr('bitcoin:$btc?amount=0.015&label=Binance')!;
      expect(p.address, btc);
      expect(p.coinSymbol, 'btc');
      expect(p.amount, '0.015');
    });

    test('uppercase scheme and address', () {
      final p = parseCryptoQr('BITCOIN:BC1QAR0SRRR7XFKVY5L643LYDNW9RE59GTZZWF5MDQ')!;
      expect(p.coinSymbol, 'btc');
      expect(p.address, 'BC1QAR0SRRR7XFKVY5L643LYDNW9RE59GTZZWF5MDQ');
    });

    test('EIP-681 native transfer strips chain id', () {
      final p = parseCryptoQr('ethereum:$evm@56?value=1e18')!;
      expect(p.address, evm);
      expect(p.amount, isNull);
    });

    test('EIP-681 token transfer uses the recipient, not the contract', () {
      const contract = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
      final p = parseCryptoQr('ethereum:$contract@1/transfer?address=$evm&uint256=1000000')!;
      expect(p.address, evm);
      expect(p.coinSymbol, isNull);
    });

    test('memo / destination tag', () {
      final p = parseCryptoQr('ripple:rLHzPsX6oXkzU2qL12kHCH8G8cnZv1rBJh?dt=123456')!;
      expect(p.memo, '123456');
      expect(p.coinSymbol, 'xrp');
    });

    test('rejects things that are not addresses', () {
      expect(parseCryptoQr('https://crownex.app/invite/abc'), isNull);
      expect(parseCryptoQr('Hello there'), isNull);
      expect(parseCryptoQr('WIFI:S:Home;T:WPA;P:secret;;'), isNull);
      expect(parseCryptoQr(''), isNull);
      expect(parseCryptoQr('bitcoin:?amount=1'), isNull);
    });

    test('ignores a malformed amount', () {
      expect(parseCryptoQr('bitcoin:$btc?amount=abc')!.amount, isNull);
    });
  });

  group('network checks', () {
    test('network families from Quidax codes/labels', () {
      expect(networkFamily('trc20', 'Tron (TRC20)'), AddressFamily.tron);
      expect(networkFamily('bep20', 'BNB Smart Chain (BEP20)'), AddressFamily.evm);
      expect(networkFamily('erc20', 'Ethereum (ERC20)'), AddressFamily.evm);
      expect(networkFamily('btc', 'Bitcoin'), AddressFamily.bitcoin);
      expect(networkFamily('sol', 'Solana'), AddressFamily.solana);
      expect(networkFamily('bch', 'Bitcoin Cash'), AddressFamily.unknown);
      expect(networkFamily('xrp', 'Ripple'), AddressFamily.unknown);
    });

    test('address fits its network', () {
      expect(addressFitsFamily(tron, AddressFamily.tron), isTrue);
      expect(addressFitsFamily(evm, AddressFamily.evm), isTrue);
      expect(addressFitsFamily(btc, AddressFamily.bitcoin), isTrue);
      expect(addressFitsFamily(btc.toUpperCase(), AddressFamily.bitcoin), isTrue);
      expect(addressFitsFamily('anything', AddressFamily.unknown), isTrue);
    });

    test('catches the classic wrong-network mistakes', () {
      expect(addressFitsFamily(tron, AddressFamily.evm), isFalse);
      expect(addressFitsFamily(evm, AddressFamily.tron), isFalse);
      expect(addressFamily(tron), AddressFamily.tron);
      expect(addressFamily(evm), AddressFamily.evm);
    });
  });
}
