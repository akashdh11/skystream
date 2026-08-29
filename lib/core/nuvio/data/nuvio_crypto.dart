import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:pointycastle/export.dart' as pc;

/// Native half of the crypto surface Nuvio scrapers expect.
///
/// Real providers reach for `crypto-js` (AES + digests), WebCrypto digests and
/// `crypto.getRandomValues`. QuickJS ships none of that, so the JS side calls
/// through one bridge channel and this class does the work with `package:crypto`
/// and PointyCastle. Everything is hex in / hex out to keep the bridge textual.
class NuvioCrypto {
  static final Random _random = Random.secure();

  /// Handles one `{op: …}` request. Returns hex (or `__NUVIO_ERR__<message>`,
  /// which the JS side turns back into a thrown Error).
  static String handle(Map<String, dynamic> request) {
    try {
      final op = request['op']?.toString() ?? '';
      switch (op) {
        case 'digest':
          return _hex(_digest(_alg(request['alg']), _bytes(request['data'])));
        case 'hmac':
          return _hex(
            Uint8List.fromList(
              c.Hmac(
                _hasher(_alg(request['alg'])),
                _bytes(request['key']),
              ).convert(_bytes(request['data'])).bytes,
            ),
          );
        case 'pbkdf2':
          return _hex(
            _pbkdf2(
              alg: _alg(request['alg']),
              password: _bytes(request['pass']),
              salt: _bytes(request['salt']),
              iterations: (request['iterations'] as num?)?.toInt() ?? 1000,
              bits: (request['bits'] as num?)?.toInt() ?? 256,
            ),
          );
        case 'aes_encrypt':
        case 'aes_decrypt':
          return _hex(
            _aes(
              encrypt: op == 'aes_encrypt',
              mode: request['mode']?.toString() ?? 'AES-CBC',
              key: _bytes(request['key']),
              iv: _bytes(request['iv']),
              data: _bytes(request['data']),
            ),
          );
        case 'random':
          final count = (request['bytes'] as num?)?.toInt() ?? 0;
          return _hex(
            Uint8List.fromList(
              List<int>.generate(
                count.clamp(0, 1 << 16),
                (_) => _random.nextInt(256),
              ),
            ),
          );
        default:
          return '__NUVIO_ERR__unsupported crypto op: $op';
      }
    } catch (error) {
      return '__NUVIO_ERR__$error';
    }
  }

  // --- helpers -------------------------------------------------------------

  static String _alg(dynamic raw) {
    final name = (raw?.toString() ?? 'SHA256').toUpperCase().replaceAll(
      RegExp('[^A-Z0-9]'),
      '',
    );
    return const {
          'MD5',
          'SHA1',
          'SHA224',
          'SHA256',
          'SHA384',
          'SHA512',
        }.contains(name)
        ? name
        : 'SHA256';
  }

  static c.Hash _hasher(String alg) => switch (alg) {
    'MD5' => c.md5,
    'SHA1' => c.sha1,
    'SHA224' => c.sha224,
    'SHA384' => c.sha384,
    'SHA512' => c.sha512,
    _ => c.sha256,
  };

  static Uint8List _digest(String alg, Uint8List data) =>
      Uint8List.fromList(_hasher(alg).convert(data).bytes);

  static Uint8List _pbkdf2({
    required String alg,
    required Uint8List password,
    required Uint8List salt,
    required int iterations,
    required int bits,
  }) {
    final pc.Digest digest = switch (alg) {
      'MD5' => pc.MD5Digest(),
      'SHA1' => pc.SHA1Digest(),
      'SHA384' => pc.SHA384Digest(),
      'SHA512' => pc.SHA512Digest(),
      _ => pc.SHA256Digest(),
    };
    final blockLength = switch (alg) {
      'SHA384' || 'SHA512' => 128,
      _ => 64,
    };
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(digest, blockLength))
      ..init(pc.Pbkdf2Parameters(salt, iterations, (bits / 8).ceil()));
    return derivator.process(password);
  }

  static Uint8List _aes({
    required bool encrypt,
    required String mode,
    required Uint8List key,
    required Uint8List iv,
    required Uint8List data,
  }) {
    final normalized = mode.toUpperCase();
    final noPadding = normalized.contains('NOPADDING');

    if (normalized.contains('GCM')) {
      final cipher = pc.GCMBlockCipher(pc.AESEngine())
        ..init(
          encrypt,
          pc.AEADParameters(
            pc.KeyParameter(key),
            128,
            iv.isEmpty ? Uint8List(12) : iv,
            Uint8List(0),
          ),
        );
      return cipher.process(data);
    }

    if (normalized.contains('CTR')) {
      final cipher = pc.CTRStreamCipher(pc.AESEngine())
        ..init(encrypt, pc.ParametersWithIV(pc.KeyParameter(key), _iv16(iv)));
      return cipher.process(data);
    }

    final pc.BlockCipher base = normalized.contains('ECB')
        ? pc.ECBBlockCipher(pc.AESEngine())
        : pc.CBCBlockCipher(pc.AESEngine());

    final params = normalized.contains('ECB')
        ? pc.KeyParameter(key)
        : pc.ParametersWithIV<pc.KeyParameter>(pc.KeyParameter(key), _iv16(iv));

    if (noPadding) {
      base.init(encrypt, params);
      final out = Uint8List(data.length);
      var offset = 0;
      while (offset < data.length) {
        offset += base.processBlock(data, offset, out, offset);
      }
      return out;
    }

    final padded = pc.PaddedBlockCipherImpl(pc.PKCS7Padding(), base)
      ..init(
        encrypt,
        pc.PaddedBlockCipherParameters<
          pc.CipherParameters,
          pc.CipherParameters
        >(params, null),
      );
    return padded.process(data);
  }

  static Uint8List _iv16(Uint8List iv) {
    if (iv.length == 16) return iv;
    final out = Uint8List(16);
    for (var i = 0; i < iv.length && i < 16; i++) {
      out[i] = iv[i];
    }
    return out;
  }

  static Uint8List _bytes(dynamic hex) {
    final text = (hex?.toString() ?? '').replaceAll(RegExp('[^0-9a-fA-F]'), '');
    final even = text.length.isEven ? text : '0$text';
    final out = Uint8List(even.length ~/ 2);
    for (var i = 0; i < even.length; i += 2) {
      out[i ~/ 2] = int.parse(even.substring(i, i + 2), radix: 16);
    }
    return out;
  }

  static String _hex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// Convenience for tests and callers that speak JSON.
  static String handleJson(String payload) =>
      handle(jsonDecode(payload) as Map<String, dynamic>);
}
